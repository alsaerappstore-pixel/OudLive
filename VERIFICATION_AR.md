# نتائج التحقق — 2026-09-29

## نُفّذ محليًا على Windows

- بُني قلب معالجة الصوت C++17 بواسطة Zig 0.14.1 / Clang، مع `-O2 -Wall -Wextra -Werror`. تبقى assertions مفعّلة صراحةً في الاختبارات.
- نجحت 11 حالة فحص: تجاوز جاف دون تأخير عينات إضافي، EQ عند 180 Hz، ضغط الإشارة، توقيت الصدى، ذيل Reverb، Chorus، Flanger، Doubler، وقيم الخرج والكتم ومدخلات NaN عند 44.1 و48 و96 kHz.
- فُحصت بنية مشروع Xcode وروابط ملفاته ومخطط البناء، XML وملفات الخصوصية والأصول، تطابق فهارس التحكم بين Swift وC++، وسلامة حزمة المصدر.

## نُفّذ على macOS عبر GitHub Actions

- نجح تجميع Swift وObjective-C++ باستخدام Xcode 16.4 وiPhoneOS 18.5 SDK، والحد الأدنى iOS 16.
- نجحت الاختبارات الـ11 مع AddressSanitizer وUndefinedBehaviorSanitizer.
- أُنتج `OudLive-unsigned.ipa` واجتاز فحص arm64 وiPhoneOS وبنية ZIP.
- [البناء الناجح](https://github.com/alsaerappstore-pixel/OudLive/actions/runs/36586931107) للنسخة `880327091c0b7a38d3df9819821fa4177d5354d7`.

## لم يُنفّذ بعد

- توقيع IPA وتثبيته بـ Sideloadly على جهاز المستخدم.
- تشغيل الواجهة وVoiceOver واختبار الصوت والتأخير والحرارة والخلفية على iPhone.

نجاح البناء واختبارات DSP لا يعادل اختباره على الهاتف. لا يزال يلزم التثبيت وتجربة صوت فعلية.

## سجل DSP

```text
PASS: dry bypass has no added sample delay
PASS: low EQ +6 dB measured at 180 Hz
PASS: compressor reduces a sustained loud tone
PASS: first echo at 100 ms and zero feedback prevents repeats
PASS: reverb has a decaying stereo tail
PASS: chorus produces independent stereo voices
PASS: flanger produces independent stereo voices
PASS: doubler produces independent stereo voices
PASS: bounded output, NaN rejection, mute at 44100 Hz
PASS: bounded output, NaN rejection, mute at 48000 Hz
PASS: bounded output, NaN rejection, mute at 96000 Hz
All DSP checks passed. Device latency and iOS integration still require hardware testing.
```
