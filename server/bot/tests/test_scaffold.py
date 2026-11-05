def test_policy_imports_and_base_loads():
    import torch
    from policy.model import PolicyNet
    net = PolicyNet()
    net.load_state_dict(torch.load("models/base.pt", weights_only=True))
    assert sum(p.numel() for p in net.parameters()) == 21 * 32 + 32 + 32 * 12 + 12


def test_store_accepts_any_safe_slug(tmp_path):
    from policy.model import Delta
    from policy.store import Store
    s = Store(tmp_path)
    s.save("u", "dry-ops-partner", Delta.zeros())
    assert s.load("u", "dry-ops-partner").norm() == 0.0
