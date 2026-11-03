# Application overview crashes and recovery page is unresponsive

**Status:** Reported on the Ubuntu 26.04 / GNOME Shell 50.1 guest `alan@192.168.122.115`. Selecting the application overview crashes the RPC shell; the resulting recovery page does not respond. The failing process, error, and reproduction boundary are not yet established.

## Reproduction

Start the built GNOME Shell RPC session on the guest, select the application overview, then inspect the client/server logs and any new core. The exact scripted reproduction command will be recorded after the first prove.

## LLM efforts

- 2026-11-03 23:21. User reported that selecting the application overview crashes the session and leaves an unresponsive recovery page. Opened this report before investigation.
