# تحقق الإصدار 3.0

- نجح بناء تطبيق iPhone arm64 وتهيئة IPA غير الموقّع للتثبيت عبر Sideloadly.
- نجحت اختبارات DSP الـ19 مع أدوات كشف أخطاء الذاكرة والسلوك غير المحدد.
- نجحت اختبارات WAV المعالج، وحفظ الإعدادات وترحيلها، وتصدير MP4 بصوت معالج والتحقق من مساراته والتزامن على عينات اختبارية.
- البناء: https://github.com/alsaerappstore-pixel/OudLive/actions/runs/37074672948
- ملف التثبيت: https://github.com/alsaerappstore-pixel/OudLive/actions/runs/37074672948/artifacts/11255333393
- إضافة الصور تستخدم PhotoKit بإذن الإضافة فقط، وتصدّر MP4 النهائي دون إعادة معالجة صوته. [مرجع Apple](https://developer.apple.com/documentation/photos/phassetchangerequest/creationrequestforassetfromvideo(atfileurl:)).

راجع design-qa.md لنتيجة مقارنة الواجهات. الاختبارات الآلية لا تعوض تجربة الميكروفون والبلوتوث والكاميرا على iPhone حقيقي. لم يُختبر مسار إذن الصور والحفظ في مكتبة جهاز المستخدم؛ يلزم بعد التحديث تسجيل فيديو قصير، حفظه في الصور، والتحقق من الصورة والصوت. جرّب رفض الإذن وإعادة منحه، وتحقق من بقاء الأصل بعد الحفظ.
