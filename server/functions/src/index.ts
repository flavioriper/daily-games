import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

initializeApp();

/** Shared handle; the real functions arrive in the next task. */
export const db = getFirestore();
