extends Node

## The one door to the store: owns `remove_ads` or not, its price, buy and
## restore. Screens use this and never godot-iap, the rule core/ads.gd keeps
## for ads. The owned flag is saved in user://store.cfg so it holds offline,
## and it is checked against the store on every launch, so a refund clears it
## -- but only on a query that succeeded: offline is not a refund.
## Off a phone there is no store: available() is false and buy() fails with
## "unavailable". A debug build run with STORE_FAKE=1 buys and restores at
## once, so the flow can be walked on the desktop.
## Spec: docs/superpowers/specs/2026-09-25-ads-and-remove-ads-design.md, section 3.

signal owned_changed(owned: bool)
signal purchase_failed(reason: String)
signal price_ready
signal busy_changed(busy: bool)

const Analytics = preload("res://core/analytics.gd")
const PRODUCT := "remove_ads"
const TYPES_PATH := "res://addons/godot-iap/types.gd"
static var save_path := "user://store.cfg"

var _iap: Node
var _types: Script
var _owned := false
var _price := ""
var _busy := false
var _fake := false

func _ready() -> void:
	_owned = _load_owned()
	_fake = OS.is_debug_build() and OS.get_environment("STORE_FAKE") == "1"
	if _fake:
		_price = "$1.99"
		return
	if not OS.has_feature("mobile"):
		return
	_iap = get_node_or_null("/root/GodotIapPlugin")
	if _iap == null or not ResourceLoader.exists(TYPES_PATH):
		_iap = null
		return
	_types = load(TYPES_PATH)
	_iap.purchase_updated.connect(_on_purchase_updated)
	_iap.purchase_error.connect(_on_purchase_error)
	_connect.call_deferred()

func owns_remove_ads() -> bool:
	return _owned

func available() -> bool:
	return _fake or _iap != null

func price_text() -> String:
	return _price

func is_busy() -> bool:
	return _busy

func buy() -> void:
	if _busy or _owned:
		return
	Analytics.track("purchase_started", {"product": PRODUCT})
	if _fake:
		_set_owned(true)
		Analytics.track("purchase_complete", {"product": PRODUCT})
		return
	if _iap == null:
		_fail("unavailable")
		return
	_set_busy(true)
	var platforms = _types.RequestPurchasePropsByPlatforms.new()
	platforms.apple = _types.RequestPurchaseIosProps.new()
	platforms.apple.sku = PRODUCT
	platforms.google = _types.RequestPurchaseAndroidProps.new()
	platforms.google.skus = [PRODUCT] as Array[String]
	await _iap.request_purchase(_types.RequestPurchaseProps.in_app(platforms))
	# The outcome arrives on purchase_updated or purchase_error.

func restore() -> void:
	if _busy:
		return
	if _fake:
		_set_owned(true)
		Analytics.track("restore_used", {"found": true})
		return
	if _iap == null:
		_fail("unavailable")
		return
	_set_busy(true)
	if _iap.has_method("restore_purchases"):
		await _iap.restore_purchases()
	var found := await _sync_owned()
	_set_busy(false)
	Analytics.track("restore_used", {"found": found})
	if not found:
		_fail("nothing_to_restore")

func _connect() -> void:
	if not await _iap.init_connection():
		return
	var request = _types.ProductRequest.new()
	request.skus = [PRODUCT] as Array[String]
	request.type = _types.ProductQueryType.IN_APP
	var products: Array = await _iap.fetch_products(request)
	for p in products:
		if String(p.id) == PRODUCT:
			_price = String(p.display_price)
			price_ready.emit()
	await _sync_owned()

## Reads the store's current purchases. Returns whether remove_ads is among
## them; clears the flag only when the query itself succeeded.
func _sync_owned() -> bool:
	var result: Dictionary = await _iap.get_available_purchases_result()
	if not result.get("success", false):
		return _owned
	var found := false
	for p in result.get("purchases", []):
		var d: Dictionary = p if p is Dictionary else p.to_dict()
		if String(d.get("productId", "")) == PRODUCT and String(d.get("purchaseState", "purchased")) == "purchased":
			found = true
			await _iap.finish_transaction_dict(d, false)
	_set_owned(found)
	return found

func _on_purchase_updated(purchase: Dictionary) -> void:
	if String(purchase.get("productId", "")) != PRODUCT:
		return
	match String(purchase.get("purchaseState", "")):
		"purchased":
			# Acknowledge at once: Play refunds anything left unacknowledged
			# for three days, and StoreKit replays an unfinished transaction.
			await _iap.finish_transaction_dict(purchase, false)
			_set_busy(false)
			_set_owned(true)
			Analytics.track("purchase_complete", {"product": PRODUCT})
		"pending":
			# Play's slow payment methods: not owned until it completes.
			_set_busy(false)
			_fail("pending")

func _on_purchase_error(error: Dictionary) -> void:
	_set_busy(false)
	_fail(String(error.get("code", "unknown")))

func _fail(reason: String) -> void:
	Analytics.track("purchase_failed", {"reason": reason})
	purchase_failed.emit(reason)

func _set_busy(value: bool) -> void:
	if _busy != value:
		_busy = value
		busy_changed.emit(value)

func _set_owned(value: bool) -> void:
	if _owned == value:
		return
	_owned = value
	var cfg := ConfigFile.new()
	cfg.set_value("store", PRODUCT, value)
	cfg.save(save_path)
	owned_changed.emit(value)

func _load_owned() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(save_path) == OK and bool(cfg.get_value("store", PRODUCT, false))
