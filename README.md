# ObjectCache
классическая задача двухуровневого кеша в Delphi реализации

Реализовать двухуровневый кэш для хранения объектов (Всё, что унаследовано от TObject). Первый уровень – оперативная память, второй – файловая система. Кэш должен реализовывать две стратегии (по частоте использования и по времени последнего использования), которые могут меняться настройкой. Максимальный размер каждого из уровней должен быть настраиваемым

Аналогичную задачу дают для языка Java где все хорошо и с объектами (их не надо уничтожать в явном виде) и с сериализацией. 
