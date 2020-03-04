# ObjectCache
классическая задача двухуровневого кеша в Delphi реализации

_Реализовать двухуровневый кэш для хранения объектов (Всё, что унаследовано от TObject). Первый уровень – оперативная память, второй – файловая система. Кэш должен реализовывать две стратегии (по частоте использования и по времени последнего использования), которые могут меняться настройкой. Максимальный размер каждого из уровней должен быть настраиваемым_

Аналогичную задачу дают для языка Java где все относительно хорошо и с объектами (их не надо уничтожать в явном виде) и с сериализацией. Было интересно, как это все получиться в Delphi. 

Получилось не очень. Текущая реализация просто сериализует объекты в Json строки и хранит их в памяти и на диске. По сути это многоуровневый кеш строк. Быстродействие подобного решения оставляет желать лучшего.

Если в памяти хранить сами объекты то тогда непонятно кто их в конце должен уничтожить... 
Возможно если возвращать объект в обертке из интерфейса, но это на будущее.
