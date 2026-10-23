# Battery and sleep notes

Modern Windows PCs may support `S0 Low Power Idle` (Modern Standby) rather than classic S3 sleep. A laptop losing ~80% battery charge in a few hours while supposedly sleeping requires investigation.

- Inspect `powercfg /a` for available sleep states.
- Generate `powercfg /batteryreport` and compare **Design Capacity** with **Full Charge Capacity**. Battery health (%) = 100 × Full / Design; this is an estimate, not a run-time guarantee.
- Generate `powercfg /sleepstudy` on Modern Standby machines to identify active periods and power drain.
- Run `scripts/03-after-sleep-test.ps1` immediately after a reproducible sleep test.
- If Sleep is unstable, use `Hibernate` for lid closure while investigating. Hibernate does write RAM state to SSD, but is generally acceptable on modern NVMe SSDs.
- Check for firmware, power-management drivers, USB devices, network wake and unexpected active requests; avoid unofficial registry hacks to force unsupported S3 sleep.
- If the **BIOS** clock resets after losing power, investigate RTC hardware/battery, separate from Windows time-zone settings.

Do not treat a sleep-to-hibernate timeout as proof that the machine really enters low-power state: check actual reports after a test.
