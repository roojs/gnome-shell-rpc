# GiMock ctor mints GIR return type (Effect*) not leaf class

**Status:** ✔️ fixed upstream — HelperMock workaround removed

**Upstream:** [`OLLMchat/docs/bugs/done/2026-09-06-FIXED-gimock-ctor-mints-return-type-not-class.md`](../../../../../gitlive/OLLMchat/docs/bugs/done/2026-09-06-FIXED-gimock-ctor-mints-return-type-not-class.md)

**Hit:** 2026-09-06 — `gi-rpc-smoke` Panel / `Clutter-BrightnessContrastEffect.new`

**Fix:** GiMock `mock_new` mints wire method prefix (`Clutter-BrightnessContrastEffect`) before falling back to `get_return_type()`.
