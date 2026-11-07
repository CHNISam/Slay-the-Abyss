# Defect engine pure-plan responsibilities

Owner-assigned continuation of TASK-74.20, not a duplicate autonomous claim. Latest develop remains 2ad07111; #541, #543 and #545 have active owners. Build on our exact #546 source tree (remote35d392bc), without changing its branch or the other owners' production files.

- Freeze the complete existing engine source and first prove the CC15 responsibility contract fails for planEffect64.
- Separate instance-change planning, direct effects, lazy repetition and X-orb planning by their real effect responsibility. Keep one public planEffect API, immutable inputs, the existing plan shape, dynamic owners and the same require edges. Do not move commit ownership or RNG mutation into planning.
- Compare separate old/current VMs over complete state graphs and returned plans, including existing end-to-end engine fixtures and explicit failure/alias/RNG edges. Preserve all historical sources and add only an exact one-owner inverse epoch with fresh source checks and CRLF coverage.
- Add each selected root and nested callback to the original CC15 gate, measure the entire source inventory and exact dependency/SCC graphs, register the added test without fabricated timings or altered budgets.
- Obtain exact independent review and publish a separate dependent Draft while upstream remains unmerged; no duplicate Full, user computer, feature-branch merge, or changed admission rules.
