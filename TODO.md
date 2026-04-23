TODO

- LogMultiBlock: блок, состоящий из других блоков: LogMessage, LogData, LogStackTrace
- LogData - отдельный блок для данных
- обычную data выводить в одной строке, a MultiData в разных
  если есть и error, и data, то режим multiline:

  1. 'query', data: LoggableMultiData(...)
     ```yaml
     query:
     HEADERS: {...}
     BODY: {...}
     ```

  2. 'response', data: {...}
     ```yaml
     response: {...}
     ```

  3. 'response', data: LoggableNamedData(...)
     ```yaml
     response:
     RESPONSE: {...}
     ```
  4. 'response', error: ...
     ```yaml
     response: error
     ```

  5. 'response', data: {...}, error: ...
     ```yaml
     response: error
     DATA: {...}
     ERROR: {...}
     ```


- Loggable: prop, который можно пропустить, т.к. он выведен через view
  (не для UI): hiddenProp?
- Loggable: виртуальный prop (не для UI): virtualProp?
- добавить active/inactive с возможностью раздельного форматирования
  - например, неактивные выводить в одну строку (соответственно, раздельные maxLength, maxLines)
  - отдельная неактивная тема передавать
