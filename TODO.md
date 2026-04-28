TODO

- Add `enumDotShorthand` to `objectToString` and etc
- LogMultiBlock: блок, состоящий из других блоков: LogMessage, LogData, LogStackTrace
- LogData - отдельный блок для данных
- Loggable: prop, который можно пропустить, т.к. он выведен через view
  (не для UI): hiddenProp?
- Loggable: виртуальный prop (не для UI): virtualProp?
- добавить active/inactive с возможностью раздельного форматирования
  - например, неактивные выводить в одну строку (соответственно, раздельные maxLength, maxLines)
  - отдельная неактивная тема передавать
