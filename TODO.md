# TODO

- для Iterable параметр в конфиге, чтобы использовать
  efficientLengthIterableToString.
- дефолтный конфиг (сейчас настройки напрямую в теме) и force-конфиг для
  игнорирования настроек пользователя:
  defaultConfig <- userConfig <- forceConfig
- Сделать возможным добавление собственных уровней и собственных функций
  логирования.
- Обрезка Map лимитами коллекций (сейчас Map не ограничивается вообще).
- Безопасный режим против ANSI-инъекций из значений (блокируется двойным
  форматированием в Prop.toLogString — решать вместе с default/force
  конфигами).
- Фикс наследования publisher в logger_builder (по-уровневый linked-флаг):
  точечный override уровня отвязывает ребёнка целиком.
- Ширина wide-символов (CJK, эмодзи) считается в code units — колонки
  съезжают; нужен учёт восточноазиатской ширины.
- Тест на copyWith(stackTrace: не-StackTrace): сейчас сырой runtime
  TypeError (внутри transformer'а fail-closed, утечки нет); опционально —
  ArgumentError с внятным сообщением (находка финального ревью 0.5.2).

README:

- [ ] lazy messages
- [ ] output: print/log
- [ ] zones
