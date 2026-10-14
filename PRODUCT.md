# DevPurge GUI

For developers who want to understand local cache usage and reclaim space without
memorizing CLI flags. The existing DevPurge scanner is the source of truth.

The main workflow is scan, inspect, select eligible targets, review the exact
selection and cleanup mode, then execute. Nothing is selected or cleaned on launch.
Unsupported or active locations remain visible with a reason and cannot be selected.
A result list records removed, rescued, pruned, skipped, and failed targets.

Show stored sizes separately from actual free disk space. Do not promise that
stored sizes equal reclaimable bytes. Preserve ignored groups and rescue settings.
No scheduler, cloud account, analytics, or remote service is needed.
