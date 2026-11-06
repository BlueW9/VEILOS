# VEILOS

**English** · [العربية](#العربية)

VEILOS is an open-source, privacy-focused Linux distribution based on **Debian Stable** with the GNOME desktop. It ships hardened defaults, no telemetry, encrypted DNS, and a set of privacy-respecting apps, in **English and Arabic**.

> **Status: early development.** The ISO builds automatically on GitHub Actions, but it has **not been fully tested yet**. Do not rely on it for sensitive work until a tested release is published.

## What's included

| Area | Included |
|---|---|
| Base | Debian Stable, GNOME, English + Arabic (Alt+Shift to switch layout) |
| Updates | Automatic security updates (`unattended-upgrades`) and daily Flatpak updates |
| Network | `nftables` firewall (all incoming blocked by default), Quad9 DNS-over-TLS with an on/off switch |
| Hardening | AppArmor, kernel/network `sysctl` hardening, rare protocols disabled, hardened kernel parameters in the installer |
| Privacy | No telemetry or crash reporting, popularity-contest removed, GNOME location and usage stats off, screen lock with password |
| Protection | ClamAV with on-access scanning of `/home` |
| Browser | LibreWolf (default) |
| Apps | LibreOffice, VLC, FreeTube, Standard Notes, Signal, SimpleX Chat |
| Proton | Proton VPN, Proton Pass, Proton Authenticator |
| Email | AsterMail |

Full-disk encryption is available in the installer (choose *Guided – encrypted LVM*). It is **not** enabled automatically.

## Honest security notes

- No system can promise it is "impossible to hack". VEILOS aims for strong, sensible defaults and fast updates, not absolute guarantees.
- **Update trust differs per app:**
  - Signed apt repositories (Debian, LibreWolf, Proton VPN, Signal) are verified by apt.
  - Flatpak apps (FreeTube, Standard Notes, SimpleX) are updated from Flathub.
  - **AsterMail, Proton Pass and Proton Authenticator** are distributed only as `.deb` files. A small updater (`veilos-app-update`) downloads the latest `.deb` over HTTPS from the vendor and installs it only if the package name matches and the version is newer. This is weaker than a signed repository.
- ClamAV on Linux is a complement, not a shield. It uses noticeable RAM.
- Strict encrypted DNS can break captive portals (hotel or café Wi-Fi). Use the *Quad9 DNS: Disable* launcher temporarily, then enable it again.
- Secure Boot is not configured yet.

## Build it yourself

The ISO is built with `live-build` inside a Debian container by GitHub Actions.

1. Fork or clone this repository.
2. Open **Actions → Build VEILOS ISO → Run workflow**.
3. When it finishes, the run **Summary** shows whether every app installed, and the ISO is available under **Artifacts** (kept for 14 days).

You can also run `build-phase1.sh` on a Debian/Ubuntu machine.

## License and trademarks

VEILOS's own scripts and configuration are released under the **GPL-3.0** license (see `LICENSE`). Included software keeps its own licenses. Proton, Signal, SimpleX, LibreWolf, Debian and other names are trademarks of their respective owners; VEILOS is not affiliated with or endorsed by them.

---

# العربية

**VEILOS** نظام لينكس مفتوح المصدر يركّز على الخصوصية، مبني على **Debian Stable** وبيئة GNOME، بإعدادات أمان قوية افتراضياً، وبلا تلمتري، وبتشفير DNS، ومجموعة تطبيقات تحترم الخصوصية، وبدعم **العربية والإنجليزية**.

> **الحالة: قيد التطوير المبكر.** يُبنى الـ ISO تلقائياً على GitHub Actions، لكنه **لم يُختبر كاملاً بعد**. لا تعتمد عليه في أعمال حساسة حتى يصدر إصدار مُختبَر.

## ما الذي يتضمنه

| المجال | المحتوى |
|---|---|
| الأساس | Debian Stable وGNOME، عربي + إنجليزي (التبديل بـ Alt+Shift) |
| التحديثات | تحديثات أمنية تلقائية، وتحديث يومي لتطبيقات Flatpak |
| الشبكة | جدار ناري `nftables` (يمنع كل الاتصالات الواردة)، وQuad9 مشفّر (DNS-over-TLS) مع مفتاح تشغيل/إيقاف |
| التقوية الأمنية | AppArmor، وإعدادات تقوية للنواة والشبكة، وتعطيل بروتوكولات نادرة |
| الخصوصية | بلا تلمتري ولا تقارير أعطال، وإزالة popularity-contest، وإيقاف الموقع وإحصاءات الاستخدام، وقفل شاشة بكلمة مرور |
| الحماية | ClamAV مع فحص فوري لمجلد `/home` |
| المتصفح | LibreWolf (الافتراضي) |
| التطبيقات | LibreOffice وVLC وFreeTube وStandard Notes وSignal وSimpleX Chat |
| Proton | Proton VPN وProton Pass وProton Authenticator |
| البريد | AsterMail |

تشفير القرص الكامل متاح في المثبّت (اختر *Guided – encrypted LVM*)، لكنه **ليس مفعّلاً تلقائياً**.

## ملاحظات أمنية بصراحة

- لا يوجد نظام يستطيع ضمان أنه «لا يُخترق». هدف VEILOS إعدادات قوية ومعقولة وتحديثات سريعة، دون وعود مطلقة.
- **الثقة في التحديثات تختلف بحسب التطبيق:**
  - مستودعات apt الموقّعة (Debian وLibreWolf وProton VPN وSignal) يتحقق منها apt.
  - تطبيقات Flatpak (FreeTube وStandard Notes وSimpleX) تتحدث من Flathub.
  - **AsterMail وProton Pass وProton Authenticator** تُوزَّع بملفات `.deb` فقط. وهناك برنامج تحديث صغير (`veilos-app-update`) يحمّل أحدث ملف عبر HTTPS من موقع الشركة، ولا يثبّته إلا إذا طابق اسم الحزمة وكان الإصدار أحدث. وهذا أضعف من المستودع الموقّع.
- ClamAV على لينكس مكمّل وليس درعاً، ويستهلك ذاكرة ملحوظة.
- التشفير الصارم لـ DNS قد يعطّل صفحات الدخول في شبكات الفنادق والمقاهي. استخدم اختصار *Quad9 DNS: إيقاف* مؤقتاً ثم أعد تفعيله.
- لم يُضبط Secure Boot بعد.

## ابنِه بنفسك

يُبنى الـ ISO بأداة `live-build` داخل حاوية Debian على GitHub Actions.

1. انسخ المستودع (Fork) أو حمّله.
2. افتح **Actions ← Build VEILOS ISO ← Run workflow**.
3. عند الانتهاء يعرض **Summary** هل ثُبِّتت كل التطبيقات، ويتوفر الـ ISO في **Artifacts** (يُحفظ 14 يوماً).

ويمكنك أيضاً تشغيل `build-phase1.sh` على جهاز Debian أو Ubuntu.

## الترخيص والعلامات التجارية

سكربتات VEILOS وإعداداته مرخّصة بـ **GPL-3.0** (انظر `LICENSE`). والبرامج المضمّنة تحتفظ بتراخيصها. وأسماء Proton وSignal وSimpleX وLibreWolf وDebian وغيرها علامات تجارية لأصحابها، وVEILOS غير تابع لها ولا معتمد منها.
