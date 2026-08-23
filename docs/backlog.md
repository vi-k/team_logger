# Бэклог

Записи владельца: что хочется сделать в пакете. Агент сюда не пишет — только
читает, предлагает взять пункт в работу и удаляет сделанное после
завершения.

- Возможность добавлять собственные уровни и собственные функции
  логирования.
- README: "We make the space for the namespace path expand as new data is
  added, but we do not limit its growth". Наоборот, в данном примере
  ограничиваем.
- про output ты приводишь примеры записи в сокет и файл. но это асинхронная
  работа, а output сихронен. мы поведём пользователя по ложному пути
- README: "There is no signal marking where a log's lines end, and `output` is
  the wrong seam if you need one entry per log — implement
  a `CustomLogPublisher` instead and render the log yourself". Можем нам просто
  добавить нужные хуки о начале вывода строки и о конце вывода?
