-- ============================================================
-- Домашнее задание к лекции «SQL. Продвинутый»
-- Школа Аналитиков · учебная база hh_school
-- Автор: Морозов Артем Кириллович
-- Количество котов: 33 (столько во время лекции насчитал)
-- Сейчас пересчитал по презентации, их вроде 37 всего. 
-- ============================================================

SET search_path TO hh_school;

--=====================================
-- Задание 1
--=====================================
-- Ниже 1 часть решения с проверкой таблиц на полноту данных,
-- аномалии и т.д.:

-- 1) Звонки, не привязанные к отклику (без response_id)
SELECT
	call_id,
	response_id,
	call_at
FROM calls
WHERE response_id IS NULL
ORDER BY call_at DESC;
-- Сколько таких звонков всего
SELECT COUNT(*) AS calls_without_response
FROM calls
WHERE response_id IS NULL;
-- Таких звонков 8, их id 700244–700251. Время вывел, чтобы проверить,
-- не появились ли они в одно время. Одного общего времени у них нет.

-- 2) Звонки и сообщения с несуществующим response_id
-- Вообще внешние ключи должны защищать от появления 
-- таких записей, но все равно проверяю.
SELECT
	c.call_id,
	c.response_id
FROM calls c
LEFT JOIN responses r ON c.response_id = r.response_id 
WHERE c.response_id IS NOT NULL AND r.response_id IS NULL;

SELECT
	m.message_id,
	m.response_id
FROM messages m
LEFT JOIN responses r ON m.response_id = r.response_id 
WHERE m.response_id IS NOT NULL AND r.response_id IS NULL;
-- Таких звонков и сообщений нет.


-- 3) Проверяю на согласованность идентификаторов между таблицами
-- Проверка на несовпадение работодателя, кандидата или вакансии в звонках.
SELECT
	c.call_id,
	c.employer_id,
	v.employer_id AS real_employer_id,
	c.applicant_id,
	r.resume_id
FROM calls c
JOIN responses r ON c.response_id = r.response_id 
JOIN vacancies v ON r.vacancy_id = v.vacancy_id 
WHERE CASE
	WHEN c.employer_id = v.employer_id
		AND c.applicant_id = r.resume_id
		AND c.vacancy_id = r.vacancy_id THEN 0
	ELSE 1
END = 1;
-- то же только с сообщениями
SELECT
	m.message_id,
	m.vacancy_id,
	r.vacancy_id AS real_vacancy_id,
	m.applicant_id,
	r.resume_id
FROM messages m 
JOIN responses r ON m.response_id = r.response_id
JOIN vacancies v ON r.vacancy_id = v.vacancy_id 
WHERE CASE
	WHEN m.employer_id = v.employer_id
		AND m.applicant_id = r.resume_id
		AND m.vacancy_id = r.vacancy_id THEN 0
	ELSE 1
END = 1;
-- В результате несовпадений нет.
-- Писал через then 0, else 1 и end = 1, чтобы при совпадении всех id case возвращал 0,
-- иначе вернет 1 и c помощью end=1 добавляю в таблицу только значения с несоответствием.
-- p.s. можно было еще через true и false и end без =1, но мне кажется, что так как я сделал понятнее.

-- 4) Проверяю несовпадения vacancy_id
SELECT
	c.call_id,
	c.vacancy_id AS call_vacancy_id,
	r.vacancy_id AS response_vacancy_id
FROM calls c 
JOIN responses r ON c.response_id = r.response_id
WHERE c.vacancy_id IS DISTINCT FROM r.vacancy_id;
-- несовпадений нет.


-- 5) Может ли событие происходить в указанное время?
--Проверяю, потому что звонки и соо раньше отклика не могут существовать
SELECT 
	c.call_id,
	c.response_id,
	c.call_at,
	r.created_at
FROM calls c
JOIN responses r ON c.response_id = r.response_id 
WHERE c.call_at < r.created_at;
SELECT -- сообщения до отклика
	m.message_id,
	m.response_id,
	m.sent_at,
	r.created_at
FROM messages m 
JOIN responses r ON m.response_id = r.response_id 
WHERE m.sent_at < r.created_at;
-- В обеих проверках 0 строк.

-- 6) Отдельно проверяю события после первых 7 суток.
-- Это не ошибки, но для дальнейших расчетов понадобится.
-- Звонки за пределами 7 дней
SELECT
	c.call_id,
	r.created_at,
	c.call_at
FROM calls c
JOIN responses r ON c.response_id = r.response_id
WHERE c.call_at >= r.created_at + INTERVAL '7 days';
-- количество звонков
SELECT COUNT(*) AS calls_after_7_days
FROM calls c
JOIN responses r ON c.response_id = r.response_id
WHERE c.call_at >= r.created_at + INTERVAL '7 days';
-- Сообщения за пределами 7 дней
SELECT
	m.message_id,
	r.created_at,
	m.sent_at
FROM messages m
JOIN responses r ON m.response_id = r.response_id
WHERE m.sent_at >= r.created_at + INTERVAL '7 days';
-- количество сообщений
SELECT COUNT(*) AS messages_after_7_days
FROM messages m
JOIN responses r ON m.response_id = r.response_id
WHERE m.sent_at >= r.created_at + INTERVAL '7 days';
-- В итоге: 75 звонков и 886 сообщений
-- Сначала вывел ID событий вне периода, затем отдельно посчитал их количество.

-- 7) Проверяю все три технических тега звонков: успешному звонку нужен connected, неуспешному no_answer,
-- а звонку с ошибкой — technical_error.
SELECT
	call_id,
	status,
	call_tags
FROM calls
WHERE (status = 'successful' AND NOT ('connected' = ANY(call_tags)))
	OR (status = 'unsuccessful' AND NOT ('no_answer' = ANY(call_tags)))
	OR (status = 'error' AND NOT ('technical_error' = ANY(call_tags)))
	OR (status <> 'successful' AND 'connected' = ANY(call_tags))
	OR (status <> 'unsuccessful' AND 'no_answer' = ANY(call_tags))
	OR (status <> 'error' AND 'technical_error' = ANY(call_tags));
-- Вывелась пустая таблица, т.е. несоответствий нет.

-- 8) Проверка на соответствие длительности звонка и статуса.
-- У успешного звонка длительность положительна, у остальных она NULL.
SELECT
	call_id,
	status,
	call_duration
FROM calls
WHERE (status = 'successful' AND (call_duration IS NULL OR call_duration <= 0))
	OR (status <> 'successful' AND call_duration IS NOT NULL);
-- Тоже пустая таблица вывелась.


-- 9) Проверяю наличие полей сообщений, которые понадобятся дальше.
SELECT 
	message_id,
	message_text,
	message_meta
FROM messages
WHERE message_text IS NULL
	OR message_text = ''
	OR NULLIF(message_meta ->> 'channel', '') IS NULL
	OR (message_meta ->> 'is_read') IS NULL
	OR NOT (message_meta ? 'attachments');
-- Пропусков в этих полях нет. Если бы отсутствовал канал или признак прочтения, 
-- сообщение все равно было бы фактом общения, но расчет долей по этим атрибутам пришлось бы вести отдельно.

-- 10) Проверяю на аномальные значения
-- посмотреть статусы звонков
SELECT 
	status,
	COUNT(*) AS calls_count
FROM calls
GROUP BY status
ORDER BY calls_count DESC;
-- у 1 звонка статус error. Проверяю этот звонок.
SELECT
	call_id,
	response_id,
	status,
	call_duration,
	call_tags
FROM calls
WHERE status = 'error';
-- У него длительность NULL: измеренного времени разговора нет.
-- Статус error описывает технический исход, а не ошибку в данных.

-- 11) Есть ли нетипично большие значения длительности?
SELECT
	call_id,
	call_duration
FROM calls
WHERE status = 'successful'
ORDER BY call_duration DESC
LIMIT 10;
-- Самые длинные 10 звонков видны здесь; ниже проверю их относительно P99.

-- 12) Проверка каналов обращения на необычные
SELECT
	message_meta ->> 'channel' AS channel,
	COUNT(*) AS messages_count
FROM messages
GROUP BY message_meta ->> 'channel'
ORDER BY messages_count DESC;
-- В результате только веб (1866) и мобильное приложение (996)


-----------------------------------
-- Исследование  call_duration
-----------------------------------
WITH percentile_99 AS (
	SELECT
		PERCENTILE_CONT(0.99) WITHIN GROUP (
			ORDER BY call_duration
		) AS p99_call_duration
	FROM calls
	WHERE status = 'successful'
)
SELECT 	
	ROUND(AVG(c.call_duration), 2) AS average_call_duration,
	PERCENTILE_CONT(0.5) WITHIN GROUP (
		ORDER BY c.call_duration
	) AS median_call_duration,
	MAX(p.p99_call_duration) AS p99_call_duration,
	SUM(CASE WHEN c.call_duration > p.p99_call_duration THEN 1 ELSE 0 END)
		AS calls_more_than_p99,
	ROUND(
		AVG(CASE WHEN c.call_duration <= p.p99_call_duration
			THEN c.call_duration END), 2
	) AS avg_without_p99
FROM calls c 
CROSS JOIN percentile_99 p 
WHERE c.status = 'successful';
-- Отдельно вывожу сами звонки выше P99, чтобы ID и длительности
-- были подтверждены запросом, а не выводились по верхним 10 строкам.
WITH percentile_99 AS (
	SELECT
		PERCENTILE_CONT(0.99) WITHIN GROUP (
			ORDER BY call_duration
		) AS p99_call_duration
	FROM calls
	WHERE status = 'successful'
)
SELECT
	c.call_id,
	c.call_duration,
	p.p99_call_duration
FROM calls c
CROSS JOIN percentile_99 p
WHERE c.status = 'successful'
	AND c.call_duration > p.p99_call_duration
ORDER BY c.call_duration DESC, c.call_id;
-- Порог равен 890,4 сек (значение p99_call_duration). Выше него только 700199 (899 с) и 700159 (892 с). 


-- ВЫВОД:
-- Из 251 звонка у 8 нет response_id: их id 700244–700251. Звонки могли быть, но  конкретным 
-- откликам их привязать нельзя, поэтому дальше их не беру.
-- Несуществующих откликов, несовпадений ID и событий до отклика не нашел.
-- Еще 75 звонков и 886 сообщений произошли после первых 7 суток.
-- Это нормальное продолжение общения, просто оно вне периода.
-- Статусы звонков тоже согласуются с длительностью и техническими тегами.
-- У сообщений нет проверенных пропусков текста, канала, is_read и вложений.
-- Один звонок со статусом error не считаю ошибкой данных, т.к. у него нет измеренной длительности.
-- Для анализа длительности взял только 181 успешный звонок:
-- среднее 467,28 с, медиана 438 с, P99 890,4 с. Выше P99 два звонка: 700199 (899 с) и 700159 (892 с).
-- Если убрать только их, среднее станет 462,49 сек. Разница небольшая, и эти значения 
-- не являются слишком большими по сравнению с другими, поэтому я не буду считать их
-- ошибками и удалять. Вообще долгий разговор мог быть например реальным собеседованием.
-- Для оценки типичной длительности выбрал бы медиану, потому что она меньше зависит от
-- аномально больших значений.
-- P.s. в excel я решил вставить результат запроса "11) Есть ли нетипично большие значения длительности?"
-- (только без limit 10) и построил график с длительностью звонков (я его приложил вместе с sql файлам).
-- Этот график практически равномерно убывает, там нет сильных перекосов и аномалий, так что в данном случае
-- можно использовать и медиану, и среднее арифметическое (медиана все равно надежнее будет).
-- Для следующих заданий исключаю только события, которые нельзя надежно связать с откликом 
-- или которые выходят за выбранные 7 суток.
-- Неуспешные звонки оставляю как попытки работодателя: разговор не состоялся,
-- но сам факт действия в истории отклика есть.



--=========================
-- Задание 2
--=========================
-- Запрос 1
-- Сначала отдельно проверяю звонки и сообщения, потом объединяю их.
-- Здесь событие = сообщение работодателя или его попытка звонка.
-- Неуспешный звонок оставляю, т.к. это действие работодателя в истории отклика, хотя разговор мог не состояться.
-- UNION ALL сохраняет каждое действие, а UNION мог бы удалить одинаковые строки. 
WITH calls_7_days AS (
	SELECT 
		c.response_id,
		c.employer_id,
		c.call_id AS event_id,
		c.call_at AS event_at,
		'call' AS event_type
	FROM calls c
	JOIN responses r ON c.response_id = r.response_id
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id 
	WHERE c.caller_role = 'employer'
		AND c.call_at >= r.created_at
		AND c.call_at < r.created_at + INTERVAL '7 days'
		AND c.vacancy_id = r.vacancy_id 
		AND c.employer_id = v.employer_id 
		AND c.applicant_id = r.resume_id 
),
messages_7_days AS (
	SELECT 
		m.response_id,
		m.employer_id,
		m.message_id AS event_id,
		m.sent_at AS event_at,
		'message' AS event_type
	FROM messages m 
	JOIN responses r ON m.response_id = r.response_id
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id 
	WHERE m.sender_role  = 'employer'
		AND m.sent_at >= r.created_at
		AND m.sent_at < r.created_at + INTERVAL '7 days'
		AND m.vacancy_id = r.vacancy_id 
		AND m.employer_id = v.employer_id 
		AND m.applicant_id = r.resume_id 
),
events AS (
	SELECT 
		response_id,
		employer_id,
		event_id,
		event_at,
		event_type	
	FROM calls_7_days 
	
	UNION ALL
	
	SELECT 
		response_id,
		employer_id,
		event_id,
		event_at,
		event_type	
	FROM messages_7_days 
)
SELECT 	
	response_id,
	employer_id,
	event_id,
	event_at,
	event_type
FROM events 
ORDER BY response_id, event_at, event_type, event_id;

-- Запрос 2 (итоговый)
-- Повторяю CTE, потому что они действуют только внутри одного запроса.
-- Здесь считаю контрольные значения и отдельно проверяю, сколько было
-- успешных звонков или отправленных сообщений без учета неудачных попыток.
WITH calls_7_days AS (
	SELECT 
		c.response_id,
		c.employer_id,
		c.call_id AS event_id,
		c.call_at AS event_at,
		'call' AS event_type,
		CASE WHEN c.status = 'successful' THEN 1 ELSE 0 END AS is_successful_call_or_sent_message
	FROM calls c
	JOIN responses r ON c.response_id = r.response_id
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id 
	WHERE c.caller_role = 'employer'
		AND c.call_at >= r.created_at
		AND c.call_at < r.created_at + INTERVAL '7 days'
		AND c.vacancy_id = r.vacancy_id 
		AND c.employer_id = v.employer_id 
		AND c.applicant_id = r.resume_id 
),
messages_7_days AS (
	SELECT 
		m.response_id,
		m.employer_id,
		m.message_id AS event_id,
		m.sent_at AS event_at,
		'message' AS event_type,
		1 AS is_successful_call_or_sent_message
	FROM messages m 
	JOIN responses r ON m.response_id = r.response_id
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id 
	WHERE m.sender_role  = 'employer'
		AND m.sent_at >= r.created_at
		AND m.sent_at < r.created_at + INTERVAL '7 days'
		AND m.vacancy_id = r.vacancy_id 
		AND m.employer_id = v.employer_id 
		AND m.applicant_id = r.resume_id 
),
events AS (
	SELECT 
		response_id,
		employer_id,
		event_id,
		event_at,
		event_type,
		is_successful_call_or_sent_message
	FROM calls_7_days 
	
	UNION ALL
	
	SELECT 
		response_id,
		employer_id,
		event_id,
		event_at,
		event_type,
		is_successful_call_or_sent_message
	FROM messages_7_days 
)
SELECT
	COUNT(*) AS total_events,
	COUNT(DISTINCT response_id) AS responses_with_events,
	SUM(CASE WHEN event_type = 'call' THEN 1 ELSE 0 END) AS total_calls,
	SUM(CASE WHEN event_type = 'message' THEN 1 ELSE 0 END) AS total_messages,
	SUM(CASE WHEN event_type = 'call' AND is_successful_call_or_sent_message = 0
		THEN 1 ELSE 0 END) AS unsuccessful_call_attempts,
	COUNT(DISTINCT CASE WHEN is_successful_call_or_sent_message = 1 THEN response_id END)
		AS responses_with_sent_message_or_successful_call
FROM events;

-- Вывод:
-- 1) Получилось 1096 событий по 382 откликам: 108 звонков и 988 сообщений.
-- Из 108 звонков 30 были неуспешными или закончились технической ошибкой.
-- Поэтому 382 это отклики с действием работодателя.
-- 2) Если считать только успешный звонок или отправленное сообщение,
-- получится 374 отклика. По оставшимся 8 были только неудачные попытки звонка,
-- но response_id у них есть; это не те 8 звонков из задания 1 без привязки к отклику.
-- Сообщение могло остаться непрочитанным, поэтому не факт, что 374 были двусторонними разговорами. 
-- Для таймлайна оставляю все 1096 событий, т.к. аналитику важно видеть и попытки работодателя, и успешные обращения.


--=========================
-- Задание 3
--=========================
-- Шаг 1
-- Восстанавливаю порядок событий внутри каждого отклика.
-- Если время совпадает, сначала идет event_type, потом event_id:
-- так номер и соседние события не будут зависеть от случайного порядка строк.
-- Для LAST_VALUE нужна полная рамка, иначе он покажет тип текущего события.
WITH calls_7_days AS (
	SELECT 
		c.response_id,
		c.employer_id,
		c.call_id AS event_id,
		c.call_at AS event_at,
		'call' AS event_type
	FROM calls c
	JOIN responses r ON c.response_id = r.response_id
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id 
	WHERE c.caller_role = 'employer'
		AND c.call_at >= r.created_at
		AND c.call_at < r.created_at + INTERVAL '7 days'
		AND c.vacancy_id = r.vacancy_id 
		AND c.employer_id = v.employer_id 
		AND c.applicant_id = r.resume_id 
),
messages_7_days AS (
	SELECT 
		m.response_id,
		m.employer_id,
		m.message_id AS event_id,
		m.sent_at AS event_at,
		'message' AS event_type
	FROM messages m 
	JOIN responses r ON m.response_id = r.response_id
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id 
	WHERE m.sender_role  = 'employer'
		AND m.sent_at >= r.created_at
		AND m.sent_at < r.created_at + INTERVAL '7 days'
		AND m.vacancy_id = r.vacancy_id 
		AND m.employer_id = v.employer_id 
		AND m.applicant_id = r.resume_id 
),
events AS (
	SELECT 
		response_id,
		employer_id,
		event_id,
		event_at,
		event_type	
	FROM calls_7_days 

	UNION ALL

	SELECT 
		response_id,
		employer_id,
		event_id,
		event_at,
		event_type	
	FROM messages_7_days 
),
timeline AS (
	SELECT
		response_id,
		employer_id,
		event_id,
		event_at,
		event_type,
		ROW_NUMBER() OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
		) AS rn,
		LAG(event_at) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
		) AS previous_event_at,
		LEAD(event_type) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
		) AS next_event_type,
		COUNT(*) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
			ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
		) AS events_so_far,
		FIRST_VALUE(event_type) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
		) AS first_event_type,
		LAST_VALUE(event_type) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
			ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
		) AS last_event_type
	FROM events
)
SELECT
	response_id,
	employer_id,
	event_id,
	event_at,
	event_type,
	rn,
	previous_event_at,
	next_event_type,
	events_so_far,
	first_event_type,
	last_event_type
FROM timeline
ORDER BY response_id, event_at, event_type, event_id;
-- ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING взял из шпаргалки, 
-- чтобы LAST_VALUE показал последнее событие по отклику, а не текущее.
-- ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW по такому же принципу.

-- Шаг 2
-- Строю витрину откликов. CTE повторяю, потому что они живут только
-- в пределах одного запроса, решил не создавать представление или таблицу.
-- В первом шаге были оконные функции, а здесь типы событий удобнее взять из массива, собранного в нужном порядке.
WITH calls_7_days AS (
	SELECT 
		c.response_id,
		c.employer_id,
		c.call_id AS event_id,
		c.call_at AS event_at,
		'call' AS event_type
	FROM calls c
	JOIN responses r ON c.response_id = r.response_id
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id 
	WHERE c.caller_role = 'employer'
		AND c.call_at >= r.created_at
		AND c.call_at < r.created_at + INTERVAL '7 days'
		AND c.vacancy_id = r.vacancy_id 
		AND c.employer_id = v.employer_id 
		AND c.applicant_id = r.resume_id 
),
messages_7_days AS (
	SELECT 
		m.response_id,
		m.employer_id,
		m.message_id AS event_id,
		m.sent_at AS event_at,
		'message' AS event_type
	FROM messages m 
	JOIN responses r ON m.response_id = r.response_id
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id 
	WHERE m.sender_role  = 'employer'
		AND m.sent_at >= r.created_at
		AND m.sent_at < r.created_at + INTERVAL '7 days'
		AND m.vacancy_id = r.vacancy_id 
		AND m.employer_id = v.employer_id 
		AND m.applicant_id = r.resume_id 
),
events AS (
	SELECT 
		response_id,
		employer_id,
		event_id,
		event_at,
		event_type	
	FROM calls_7_days 

	UNION ALL

	SELECT 
		response_id,
		employer_id,
		event_id,
		event_at,
		event_type	
	FROM messages_7_days 
),
-- Для максимального промежутка достаточно времени предыдущего события.
-- Порядок тот же, что в первом шаге.
timeline AS (
	SELECT
		response_id,
		employer_id,
		event_id,
		event_at,
		event_type,
		LAG(event_at) OVER (
			PARTITION BY response_id
			ORDER BY event_at, event_type, event_id
		) AS previous_event_at
	FROM events
),

response_statistic AS (
	SELECT
		response_id,
		employer_id,
		COUNT(*) AS total_events,
		SUM(CASE WHEN event_type = 'call' THEN 1 ELSE 0 END) AS total_calls,
		SUM(CASE WHEN event_type = 'message' THEN 1 ELSE 0 END) AS total_messages,
		MIN(event_at) AS first_event_at,
		ARRAY_AGG(event_type ORDER BY event_at, event_type, event_id) AS event_types,
		MAX(EXTRACT(EPOCH FROM (event_at - previous_event_at)) / 3600)
			AS max_gap_hours
	FROM timeline
	GROUP BY response_id, employer_id
),

responses_mart AS (
	SELECT
		r.response_id,
		v.employer_id,
		v.professional_role,
		r.status,
		COALESCE(s.total_events, 0) AS total_events,
		COALESCE(s.total_calls, 0) AS total_calls,
		COALESCE(s.total_messages, 0) AS total_messages,
		s.first_event_at,
		s.event_types[1] AS first_event_type, -- собрал типы событий в массив event_types выше по порядку, чтобы сразу взять и первый, и второй.
		s.event_types[2] AS second_event_type, -- можно было еще сделать через FIRST_VALUE, LAST_VALUE, но я решил через массив.
		s.event_types[CARDINALITY(s.event_types)] AS last_event_type,
		ROUND(EXTRACT(EPOCH FROM (s.first_event_at - r.created_at)) / 3600, 2)
			AS hours_to_first_event,
		ROUND(s.max_gap_hours, 2) AS max_gap_hours
	FROM responses r
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id
	LEFT JOIN response_statistic s ON r.response_id = s.response_id
)

-- Шаг 3
-- Проверяю пять контрольных значений по витрине.
SELECT
	COUNT(*) AS total_responses,
	SUM(CASE
		WHEN total_events > 0 THEN 1
		ELSE 0
	END) AS responses_with_events,
	SUM(CASE
		WHEN total_events = 0 THEN 1
		ELSE 0
	END) AS responses_without_events,
	SUM(CASE
		WHEN first_event_type = 'message' THEN 1
		ELSE 0
	END) AS first_message,
	SUM(CASE
		WHEN first_event_type = 'call' THEN 1
		ELSE 0
	END) AS first_call
FROM responses_mart;

-- Результат запроса:
-- total_responses|responses_with_events|responses_without_events|first_message|first_call|
-- ---------------+---------------------+------------------------+-------------+----------+
--             628|                  382|                     246|          314|        68|
-- ВЫВОД:
-- 1) Получилось 628 строк (по одной на каждый отклик). По 382 откликам было действие работодателя 
-- в первые 7 дней, по 246 его не было. Среди этих 382 есть 8 откликов только с неуспешной попыткой звонка
-- 2) Эти 246 откликов я сохранил через LEFT JOIN. Если убрать их, доля откликов с действием 
-- в задании 4 окажется завышенной.
-- 3) Первым событием было сообщение у 314 откликов, звонок был у 68. 314 + 68 = 382, 
-- то есть число совпало с заданием 2. Если событий нет, счетчики равны 0, а время первого события и
-- максимальный промежуток NULL, то есть измерять там просто нечего.


--======================
-- Задание 4
--======================
-- Сравниваю работодателей отдельно внутри каждого направления.
-- Здесь использую сокращенную витрину из задания 3, такк как нужно только наличие
-- события и время первого события. Звонки с unsuccessful и error остаются событиями, 
-- поэтому доля обработанных откликов ниже означает долю откликов
-- с действием работодателя, а не долю состоявшихся разговоров.
-- В задании 3 first_event_at тоже считался как MIN(event_at) после тех же проверок ID и времени.
-- left join снова идет от responses, значит набор откликов и время первого события должны совпадать.
-- Проверил это отдельно: 628 откликов, 382 с событием, 246 без него,
-- расхождений во времени первого события нет.

WITH calls_7_days AS (
	SELECT
		c.response_id,
		c.call_at AS event_at
	FROM calls c
	JOIN responses r ON c.response_id = r.response_id
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id
	WHERE c.caller_role = 'employer'
		AND c.call_at >= r.created_at
		AND c.call_at < r.created_at + INTERVAL '7 days'
		AND c.vacancy_id = r.vacancy_id
		AND c.employer_id = v.employer_id
		AND c.applicant_id = r.resume_id
),
messages_7_days AS (
	SELECT
		m.response_id,
		m.sent_at AS event_at
	FROM messages m
	JOIN responses r ON m.response_id = r.response_id
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id
	WHERE m.sender_role = 'employer'
		AND m.sent_at >= r.created_at
		AND m.sent_at < r.created_at + INTERVAL '7 days'
		AND m.vacancy_id = r.vacancy_id
		AND m.employer_id = v.employer_id
		AND m.applicant_id = r.resume_id
),
-- Сохраняю все события, тк 2 сообщения в одно время все равно остаются двумя.
events AS (
	SELECT response_id, event_at FROM calls_7_days
	UNION ALL
	SELECT response_id, event_at FROM messages_7_days
),
-- Одна строка на отклик, по которому было событие работодателя.
first_event AS (
	SELECT
		response_id,
		MIN(event_at) AS first_event_at
	FROM events
	GROUP BY response_id
),
-- left join оставляет и отклики без событий, чтобы не завысить долю действий.
responses_mart AS (
	SELECT
		r.response_id,
		v.professional_role,
		v.employer_id,
		r.status,
		f.first_event_at,
		EXTRACT(EPOCH FROM (f.first_event_at - r.created_at)) / 3600
			AS hours_to_first_event
	FROM responses r
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id
	LEFT JOIN first_event f ON r.response_id = f.response_id
),

employer_statistic AS (
	SELECT
		professional_role,
		employer_id,
		COUNT(*) AS total_responses,
		COUNT(first_event_at) AS processed_responses,
		100.0 * COUNT(first_event_at) / COUNT(*) AS processed_share,
		PERCENTILE_CONT(0.5) WITHIN GROUP (
			ORDER BY hours_to_first_event
		) AS median_first_event_hours,
		PERCENTILE_CONT(0.9) WITHIN GROUP (
			ORDER BY hours_to_first_event
		) AS p90_first_event_hours,
		-- Число приглашений делю на все отклики работодателя и перевожу в проценты.
		100.0 * SUM(CASE WHEN status = 'invited' THEN 1 ELSE 0 END)
			/ COUNT(*) AS invitation_conversion
	FROM responses_mart
	GROUP BY professional_role, employer_id
	HAVING COUNT(*) >= 8
),
-- Сначала сравниваю долю обработанных, при равенстве по медиане времени.
-- DENSE_RANK() дает одинаковое место при полном равенстве этих двух показателей.
-- с DENSE_RANK следующее место не пропускается как и надо.
employer_ranking AS (
	SELECT
		professional_role,
		employer_id,
		total_responses,
		processed_responses,
		processed_share,
		median_first_event_hours,
		p90_first_event_hours,
		invitation_conversion,
		DENSE_RANK() OVER (
			PARTITION BY professional_role
			ORDER BY processed_share DESC,
				median_first_event_hours ASC NULLS LAST
		) AS employer_place
	FROM employer_statistic
)

-- Название компании подтягиваю после расчета мест, поэтому оно не влияет на рейтинг.
SELECT
	professional_role,
	employer_place,
	er.employer_id,
	e.employer_name,
	total_responses,
	processed_responses,
	ROUND(processed_share, 2) AS processed_share,
	ROUND(median_first_event_hours::numeric, 2) AS median_first_event_hours,
	ROUND(p90_first_event_hours::numeric, 2) AS p90_first_event_hours,
	ROUND(invitation_conversion, 2) AS invitation_conversion
FROM employer_ranking er
JOIN employers e ON er.employer_id = e.employer_id
WHERE employer_place <= 2
ORDER BY professional_role, employer_place, er.employer_id;

-- ВЫВОД:
-- В рейтинге "направление и работодатель" с 8 и более откликами.
-- При меньшем числе даже одно событие сильно меняет процент.
-- Основным критерием взял долю откликов с действием работодателя,
-- а при равенстве — медиану времени до первого события. 
-- Неуспешный звонок в этой метрике тоже действие, но не состоявшийся разговор.
-- Медиана меньше зависит от долгого ожидания в отдельных откликах, P90 показывает более медленные случаи,
-- а конверсия в приглашение это итог отклика. 
-- Места считаю до округления, чтобы не создать ничью после округления значений.
-- В направлении "Аналитик данных"  "Академия данных" совершили действие по 17 из 19 откликов (89,47%) и занял первое место. 
-- У DataWave работодателя 67 из 79 (84,81%), это второе место. Но медиана у Datawave даже 
-- ниже: 54,33 часа против 56,97 часа у академии данных.
-- По правилам задания доля обработки важнее скорости, поэтому порядок именно такой.
-- Так можно отличить работодателя, который часто что-то делает по откликам, от того,
-- который реагирует быстрее, но по меньшей части откликов.
-- Итоговый рейтинг:
-- professional_role   |employer_place|employer_id|
-- --------------------+--------------+-----------+
-- Аналитик данных     |             1|        109|
-- Аналитик данных     |             2|        103|
-- Дата-инженер        |             1|        106|
-- Дата-инженер        |             2|        101|
-- Продуктовый аналитик|             1|        103|
-- Продуктовый аналитик|             2|        102|
-- Разработчик         |             1|        112|
-- Разработчик         |             2|        104|
-- Тестировщик         |             1|        107|
-- Тестировщик         |             2|        108|

-- P.S. Дополнительная проверка витрины: сравниваю MIN(event_at) с выбором
-- самого раннего события через DISTINCT ON. Так я проверяю время не только по контрольным количествам,
-- но и по response_id. CTE здесь повторяются только потому, что проверка выполняется отдельно.
WITH calls_7_days AS (
	SELECT c.response_id, c.call_at AS event_at
	FROM calls c
	JOIN responses r ON c.response_id = r.response_id
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id
	WHERE c.caller_role = 'employer'
		AND c.call_at >= r.created_at
		AND c.call_at < r.created_at + INTERVAL '7 days'
		AND c.vacancy_id = r.vacancy_id
		AND c.employer_id = v.employer_id
		AND c.applicant_id = r.resume_id
),
messages_7_days AS (
	SELECT m.response_id, m.sent_at AS event_at
	FROM messages m
	JOIN responses r ON m.response_id = r.response_id
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id
	WHERE m.sender_role = 'employer'
		AND m.sent_at >= r.created_at
		AND m.sent_at < r.created_at + INTERVAL '7 days'
		AND m.vacancy_id = r.vacancy_id
		AND m.employer_id = v.employer_id
		AND m.applicant_id = r.resume_id
),
events AS (
	SELECT response_id, event_at FROM calls_7_days
	UNION ALL
	SELECT response_id, event_at FROM messages_7_days
),
first_by_min AS (
	SELECT response_id, MIN(event_at) AS first_event_at
	FROM events
	GROUP BY response_id
),
first_by_order AS (
	SELECT DISTINCT ON (response_id)
		response_id,
		event_at AS first_event_at
	FROM events
	ORDER BY response_id, event_at
)
SELECT
	COUNT(*) AS responses_in_mart,
	COUNT(m.first_event_at) AS responses_with_event,
	SUM(CASE WHEN m.first_event_at = o.first_event_at
		OR (m.first_event_at IS NULL AND o.first_event_at IS NULL)
		THEN 0 ELSE 1 END) AS first_event_time_mismatches
FROM responses r
LEFT JOIN first_by_min m ON r.response_id = m.response_id
LEFT JOIN first_by_order o ON r.response_id = o.response_id;
-- В итоге: 628 откликов, у 382 есть событие, расхождений по времени 0.


--======================
-- Задание 5
--======================
-- Считаю сколько времени проходит от сообщения кандидата до ответа работодателя.
WITH messages_7_days AS (
	SELECT
		m.message_id,
		m.response_id,
		m.employer_id,
		m.sender_role,
		m.sent_at
	FROM messages m
	JOIN responses r ON m.response_id = r.response_id
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id
	WHERE m.sent_at >= r.created_at
		AND m.sent_at < r.created_at + INTERVAL '7 days'
		AND m.vacancy_id = r.vacancy_id
		AND m.employer_id = v.employer_id
		AND m.applicant_id = r.resume_id
),
-- Оставляю в истории и сообщения кандидата. Если сначала выбрать только сообщения работодателя,
-- LAG() не найдет, на что он отвечал.
message_timeline AS (
	SELECT
		message_id,
		response_id,
		employer_id,
		sender_role,
		sent_at,
		LAG(sender_role) OVER (
			PARTITION BY response_id
			ORDER BY sent_at, message_id
		) AS previous_sender,
		LAG(sent_at) OVER (
			PARTITION BY response_id
			ORDER BY sent_at, message_id
		) AS previous_sent_at
	FROM messages_7_days
),
-- Беру только непосредственные ответы после сообщения кандидата.
employer_replies AS (
	SELECT
		message_id,
		response_id,
		employer_id,
		EXTRACT(EPOCH FROM (
			sent_at - previous_sent_at
		)) / 3600 AS reply_hours

	FROM message_timeline
	WHERE sender_role = 'employer' AND previous_sender = 'applicant'
),
-- Сравниваю работодателей по числу ответов и времени ожидания.
employer_time_statistic AS (
	SELECT
		employer_id,
		COUNT(*) AS replies_count,
		AVG(reply_hours) AS average_reply_hours,
		PERCENTILE_CONT(0.5) WITHIN GROUP (
			ORDER BY reply_hours
		) AS median_reply_hours,
		PERCENTILE_CONT(0.9) WITHIN GROUP (
			ORDER BY reply_hours
		) AS p90_reply_hours
	FROM employer_replies
	GROUP BY employer_id
),
-- Отдельно складываю ответы всех работодателей, без оконной суммы в каждой строке.
all_replies AS (
	SELECT SUM(replies_count) AS total_replies
	FROM employer_time_statistic
)
SELECT
	s.employer_id,
	e.employer_name,
	s.replies_count,
	ROUND(average_reply_hours, 2) AS average_reply_hours,
	ROUND(median_reply_hours::numeric, 2) AS median_reply_hours,
	ROUND(p90_reply_hours::numeric, 2) AS p90_reply_hours,
	a.total_replies
FROM employer_time_statistic s
JOIN employers e ON s.employer_id = e.employer_id
CROSS JOIN all_replies a
ORDER BY s.median_reply_hours, s.employer_id;

-- ВЫВОД:
-- Всего 749 непосредственных ответов работодателя на сообщение кандидата.
-- Самая низкая медиана времени ответа оказалась у работодателя Логистик Плюс и равна 3,93 часа (28 ответов).
-- При этом среднее у него 9,37 часа, а P90=19,90 час, то есть часть ответов приходит намного позже типичного.
-- Поэтому сравниваю работодателей по медиане, но смотрю и на P90, чтобы не скрывать долгие ожидания кандидатов.
-- Например у СебирьТелеком медиана лишь немного выше (4,12 часа), но рассчитана всего по 8 ответам.
-- Такое нужно учитывать при сравнении, потому что маленькая выборка может давать менее устойчивое значение.
-- У DataWave и Северного Кода медиана после округления одинакова 4,58 часа, но ответов 171 и 85.
-- Поэтому рядом со скоростью я показываю и размер выборки.


--=========================
-- Задание 6
--=========================
-- Задание 6.1
-- Сначала исследую call_tags.
WITH calls_7_days AS (
	SELECT
		c.call_id,
		c.status,
		c.call_tags
	FROM calls c
	JOIN responses r ON c.response_id = r.response_id
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id
	WHERE c.caller_role = 'employer'
		AND c.call_at >= r.created_at
		AND c.call_at < r.created_at + INTERVAL '7 days'
		AND c.vacancy_id = r.vacancy_id
		AND c.employer_id = v.employer_id
		AND c.applicant_id = r.resume_id
),
-- Проверяю все три технических тега, а не только connected.
checked_calls AS (
	SELECT
		call_id,
		status,
		call_tags,
		CASE
			WHEN status = 'successful'
				AND 'connected' = ANY(call_tags)
				AND NOT ('no_answer' = ANY(call_tags)
					OR 'technical_error' = ANY(call_tags)) THEN 1
			WHEN status = 'unsuccessful'
				AND 'no_answer' = ANY(call_tags)
				AND NOT ('connected' = ANY(call_tags)
					OR 'technical_error' = ANY(call_tags)) THEN 1
			WHEN status = 'error'
				AND 'technical_error' = ANY(call_tags)
				AND NOT ('connected' = ANY(call_tags)
					OR 'no_answer' = ANY(call_tags)) THEN 1
			ELSE 0
		END AS is_valid
	FROM calls_7_days
),
-- В статистику попадут только звонки без таких противоречий.
valid_calls AS (
	SELECT
		call_id,
		call_tags
	FROM checked_calls
	WHERE is_valid = 1
)

SELECT
	COUNT(*) AS valid_calls,

	SUM(CASE
		WHEN 'screening' = ANY(call_tags) THEN 1
		ELSE 0
	END) AS screening_calls,

	SUM(CASE
		WHEN 'interview' = ANY(call_tags) THEN 1
		ELSE 0
	END) AS interview_calls,

	SUM(CASE
		WHEN 'follow_up' = ANY(call_tags) THEN 1
		ELSE 0
	END) AS follow_up_calls,

	SUM(CASE
		WHEN 'details' = ANY(call_tags) THEN 1
		ELSE 0
	END) AS details_calls,

	SUM(CASE
		WHEN 'screening' = ANY(call_tags)
			OR 'interview' = ANY(call_tags)
			OR 'follow_up' = ANY(call_tags)
			OR 'details' = ANY(call_tags) THEN 1
		ELSE 0
	END) AS calls_with_business_tags,

	ROUND(AVG(CARDINALITY(call_tags)), 2)
		AS avg_tags_per_call
FROM valid_calls;

-- ВЫВОД:
-- 1) За первые 7 дней нашел 108 звонков работодателей. У всех технический
-- тег соответствует статусу, поэтому все 108 вошли в расчет.
-- 2) interview встречается у 31 звонка, follow_up — у 29,
-- screening — у 25, details — у 23. Хотя бы один из этих тегов есть
-- у каждого звонка, и сумма 31 + 29 + 25 + 23 тоже равна 108.
-- Значит, в этой выборке каждый звонок попал ровно в одну из четырех групп:
-- если бы группы пересекались, сумма была бы больше 108.
-- 3) В среднем на звонок приходится 4 тега. Сюда входят и технические,
-- поэтому это не значит, что у каждого звонка было по 4 цели.
-- По бизнестегам можно смотреть для чего звонили, но вывод о том, что группы не пересекаются,
-- относится только к этим 108 звонкам.


-- Задание 6.2
-- Извлекаю данные из json и сравниваю каналы отправки сообщений.
WITH messages_7_days AS (
	SELECT
		m.message_id,
		m.message_meta
	FROM messages m
	JOIN responses r ON m.response_id = r.response_id
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id
	WHERE m.sender_role = 'employer'
		AND m.sent_at >= r.created_at
		AND m.sent_at < r.created_at + INTERVAL '7 days'
		AND m.vacancy_id = r.vacancy_id
		AND m.employer_id = v.employer_id
		AND m.applicant_id = r.resume_id
),

-- Считаю количество вложений в json-массиве attachments. 
message_info AS (
	SELECT
		message_id,

		COALESCE(NULLIF(message_meta ->> 'channel', ''), 'unknown')
			AS channel,

		(message_meta ->> 'is_read')::boolean AS is_read,

		COALESCE(
			jsonb_array_length(message_meta -> 'attachments'),
			0
		) AS attachments

	FROM messages_7_days
),
-- Считаю показатели отдельно для каждого канала.
channel_statistic AS (
	SELECT
		channel,
		COUNT(*) AS total_messages,

		SUM(CASE
			WHEN is_read IS NOT NULL THEN 1
			ELSE 0
		END) AS known_read_status,

		SUM(CASE
			WHEN is_read = FALSE THEN 1
			ELSE 0
		END) AS unread_messages,

		SUM(CASE
			WHEN attachments > 0 THEN 1
			ELSE 0
		END) AS messages_with_attachments

	FROM message_info
	GROUP BY channel
)

SELECT
	channel,
	total_messages,
	known_read_status,
	unread_messages,

	ROUND(
		100.0 * unread_messages
			/ NULLIF(known_read_status, 0), 2
	) AS unread_share,

	messages_with_attachments,

	ROUND(
		100.0 * messages_with_attachments
			/ NULLIF(total_messages, 0), 2
	) AS attachments_share
FROM channel_statistic
ORDER BY channel;

-- ВЫВОД:
-- Получилось 988 сообщений работодателей 628 через web и 360 через mobile_app.
-- Неизвестных каналов и пропусков is_read нет, поэтому при расчете доли
-- непрочитанных использую все сообщения каждого канала.
-- В web не прочитаны 52 сообщения (8,28%), с вложениями 25 (3,98%).
-- В mobile_app не прочитаны 36 (10%), с вложениями 14 (3,89%).
-- Доля непрочитанных в mobile_app выше на 1,72 проц пункта, но не можем утверждать
-- что причина именно в канале отправки.
-- Вложения в обоих каналах встречаются чуть менше чем в 4% сообщений.
-- Сумма 628 + 360 = 988 совпала с заданием 2.


--======================
-- Задание 7
--======================
-- ГИПОТЕЗА 1: по приглашенным откликам работодатель чаще и быстрее совершает первое
-- действие пишет сообщение или пытается позвонить.
-- Проверю долю откликов с событием, медианное время первого события
-- и долю откликов, откуда оно было за 24 ч (беру такое время как удобный ориентир)

-- ГИПОТЕЗА 2: по приглашенным откликам действий работодателя больше.
-- Сравню среднее число событий, долю откликов с 3 и более событиями
-- и долю с обоими каналами. Порог 3 выбрал, чтобы отдельно посмотреть
-- отклики, где дело не ограничилось одним-двумя действиями.
-- Сравниваю текущий статус invited со всеми остальными: new, viewed, rejected.
-- В данных нет времени смены статуса, поэтому я не могу сказать,
-- какое событие было до приглашения, а какое именно после него.
-- Считаю на уровне отклика: знаменатель будут все отклики группы, в том числе без событий. 
-- Медиану времени считаю только там, где событие было.
-- Неуспешные звонки остаются событиями и здесь как в задании 2.

WITH calls_7_days AS (
	SELECT
		c.response_id,
		c.call_at AS event_at,
		'call' AS event_type
	FROM calls c
	JOIN responses r ON c.response_id = r.response_id
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id
	WHERE c.caller_role = 'employer'
		AND c.call_at >= r.created_at
		AND c.call_at < r.created_at + INTERVAL '7 days'
		AND c.vacancy_id = r.vacancy_id
		AND c.employer_id = v.employer_id
		AND c.applicant_id = r.resume_id
),
messages_7_days AS (
	SELECT
		m.response_id,
		m.sent_at AS event_at,
		'message' AS event_type
	FROM messages m
	JOIN responses r ON m.response_id = r.response_id
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id
	WHERE m.sender_role = 'employer'
		AND m.sent_at >= r.created_at
		AND m.sent_at < r.created_at + INTERVAL '7 days'
		AND m.vacancy_id = r.vacancy_id
		AND m.employer_id = v.employer_id
		AND m.applicant_id = r.resume_id
),

-- Объединяю звонки и сообщения
events AS (
	SELECT
		response_id,
		event_at,
		event_type
	FROM calls_7_days

	UNION ALL

	SELECT
		response_id,
		event_at,
		event_type
	FROM messages_7_days
),

-- Считаю количество событий и время первого действия по каждому отклику.
event_statistic AS (
	SELECT
		response_id,
		COUNT(*) AS total_events,

		SUM(CASE
			WHEN event_type = 'call' THEN 1
			ELSE 0
		END) AS total_calls,

		SUM(CASE
			WHEN event_type = 'message' THEN 1
			ELSE 0
		END) AS total_messages,

		MIN(event_at) AS first_event_at

	FROM events
	GROUP BY response_id
),
-- Собираю витрину и сохраняю отклики без событий.
response_mart AS (
	SELECT
		r.response_id,

		CASE
			WHEN r.status = 'invited' THEN 'invited'
			ELSE 'other'
		END AS response_group,

		COALESCE(s.total_events, 0) AS total_events,
		COALESCE(s.total_calls, 0) AS total_calls,
		COALESCE(s.total_messages, 0) AS total_messages,

		EXTRACT(EPOCH FROM (
			s.first_event_at - r.created_at
		)) / 3600 AS hours_to_first_event

	FROM responses r
	LEFT JOIN event_statistic s
		ON r.response_id = s.response_id
),

-- Считаю метрики для приглашенных откликов и остальных по группам
group_statistic AS (
	SELECT
		response_group,
		COUNT(*) AS total_responses,

		SUM(CASE
			WHEN total_events > 0 THEN 1
			ELSE 0
		END) AS responses_with_events,

		SUM(CASE
			WHEN hours_to_first_event <= 24 THEN 1
			ELSE 0
		END) AS first_events_24h,

		PERCENTILE_CONT(0.5) WITHIN GROUP (
			ORDER BY hours_to_first_event
		) AS median_first_event_hours,

		AVG(total_events) AS avg_events,

		SUM(CASE
			WHEN total_events >= 3 THEN 1
			ELSE 0
		END) AS responses_3plus,

		SUM(CASE
			WHEN total_calls > 0 AND total_messages > 0 THEN 1
			ELSE 0
		END) AS responses_both_channels
	FROM response_mart
	GROUP BY response_group
)

SELECT
	response_group,
	total_responses,
	responses_with_events,
	ROUND(100.0 * responses_with_events / total_responses, 2) AS event_share,
	first_events_24h,
	ROUND(100.0 * first_events_24h / total_responses, 2) AS first_events_24h_share,
	ROUND(median_first_event_hours::numeric, 2) AS median_first_event_hours,
	ROUND(avg_events, 2) AS avg_events,
	responses_3plus,
	ROUND(100.0 * responses_3plus / total_responses, 2) AS share_3plus,
	responses_both_channels,
	ROUND(100.0 * responses_both_channels / total_responses, 2) AS both_channels_share
FROM group_statistic
ORDER BY
	CASE
		WHEN response_group = 'invited' THEN 0
		ELSE 1
	END;

-- ВЫВОД ПО ГИПОТЕЗЕ 1:
-- Гипотеза полностью не подтверждается. Среди 92 откликов со статусом invited
-- событие было по 54 (58,70%), среди остальных 536 было 328 (61,19%).
-- По частоте ожидаемой разницы нет, разница всего в 2,49 процентных пункта.
-- А вот медиана времени до первого событмя у invited ниже 51,08 часа против 54,67 часа.
-- То есть по скорости разница в ожидаемую сторону есть, примерно 3,6 часа, но по
-- одной выборке нельзя судить о ее устойчивости и о причинно следственной связи.
-- За первые 24 часа действие было по 18 из 92 invited (19,57%)
-- и по 104 из 536 остальных (19,40%). эти доли почти одинаковые.
-- Но событие может быть и неуспешным звонком.
-- По этим цифрам нельзя доказать ни отсутствие связи, ни влияние скорости на приглашение.

-- ВЫВОД ПО ГИПОТЕЗЕ 2:
-- Гипотеза 2 тоже не подтверждается. На один invited-отклик приходится в среднем
-- 1,63 события, на остальные — 1,76. В среднее входят и отклики без событий, поэтому группы 
-- сравниваются честно.
-- Три и более события были по 43 из 92 invited (46,74%) и по 269 из 536 остальных (50,19%).
-- Оба канала встретились по 8 invited (8,70%) и по 57 остальных (10,63%).
-- Но по числу звонков и сообщений не видно, о чем именно общались.
-- А без даты приглашения нельзя понять, какие из этих действий были до него, а какие после.



--======================
-- Задание 8
--======================
-- ИТОГ ИССЛЕДОВАНИЯ:
-- За первые 7 дней работодатели чаще писали, чем звонили:
-- нашел 988 сообщений и 108 звонков в выборке из 628 откликов.
-- Хотя бы одно действие было по 382 откликам, но это еще не значит, 
-- что контакт состоялся: в 8 случаях была только неудачная попытка звонка.
-- Поэтому я бы отдельно показывал отклики с любым действием и отклики
-- с успешным звонком или отправленным сообщением — последних 374.
-- Работодатели действовали по-разному: в направлении «Аналитик данных» у Академии Данных 
-- событие было по 89,47% откликов, а у DataWave по 84,81%.
-- При этом у DataWave медиана времени до первого события даже ниже 54,33 против 56,97 часа, 
-- то есть более высокая доля действий не обязательно означает более быстрый ответ.
-- В переписке я насчитал 749 непосредственных ответов кандидату; самая низкая медиана 
-- времени ответа получилась у работодателя Логистик Плюс (id 107) 3,93 часа.
-- У приглашенных откликов событие встречалось чуть реже, чем у остальных (58,70% против 61,19%),
-- хотя медиана времени до первого события была немного ниже (51,08 против 54,67 часа).
-- По количеству действий ожидаемой разницы тоже нет: в среднем 1,63 события у приглашенных 
-- против 1,76 у остальных, поэтому мои гипотезы целиком не подтвердились.
-- Эти различия не доказывают влияние действий работодателя на приглашение: я смотрел только 
-- первые 7 дней и знаю текущий статус, но не время самого приглашения.
-- Дальше я бы проверил, связана ли реакция в первые сутки с приглашением у разных работодателей: 
-- для этого нужно знать время смены статуса и учитывать только действия до него.




--========================
-- Дополнение по 7 заданию
--========================
-- Дополнительно хочу проверить гипотезу внутри групп по направлениям и работодателям.

-- Проверка устойчивости 1: делю те же отклики по направлениям и сравниваю invited с остальными.
-- Это разные части одной учебной базы, а не независимые новые данные; поэтому рядом оставляю размер групп.
WITH events AS (
	SELECT c.response_id, c.call_at AS event_at
	FROM calls c
	JOIN responses r ON c.response_id = r.response_id
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id
	WHERE c.caller_role = 'employer'
		AND c.call_at >= r.created_at
		AND c.call_at < r.created_at + INTERVAL '7 days'
		AND c.vacancy_id = r.vacancy_id
		AND c.employer_id = v.employer_id
		AND c.applicant_id = r.resume_id

	UNION ALL

	SELECT m.response_id, m.sent_at AS event_at
	FROM messages m
	JOIN responses r ON m.response_id = r.response_id
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id
	WHERE m.sender_role = 'employer'
		AND m.sent_at >= r.created_at
		AND m.sent_at < r.created_at + INTERVAL '7 days'
		AND m.vacancy_id = r.vacancy_id
		AND m.employer_id = v.employer_id
		AND m.applicant_id = r.resume_id
),
event_statistic AS (
	SELECT response_id, COUNT(*) AS total_events, MIN(event_at) AS first_event_at
	FROM events
	GROUP BY response_id
),
response_mart AS (
	SELECT
		v.professional_role,
		CASE WHEN r.status = 'invited' THEN 'invited' ELSE 'other' END AS response_group,
		COALESCE(s.total_events, 0) AS total_events,
		EXTRACT(EPOCH FROM (s.first_event_at - r.created_at)) / 3600
			AS hours_to_first_event
	FROM responses r
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id
	LEFT JOIN event_statistic s ON r.response_id = s.response_id
),
group_statistic AS (
	SELECT
		professional_role,
		response_group,
		COUNT(*) AS total_responses,
		SUM(CASE WHEN total_events > 0 THEN 1 ELSE 0 END) AS responses_with_events,
		SUM(CASE WHEN hours_to_first_event <= 24 THEN 1 ELSE 0 END) AS first_events_24h,
		PERCENTILE_CONT(0.5) WITHIN GROUP (
			ORDER BY hours_to_first_event
		) AS median_first_event_hours,
		AVG(total_events) AS avg_events,
		SUM(CASE WHEN total_events >= 3 THEN 1 ELSE 0 END) AS responses_3plus
	FROM response_mart
	GROUP BY professional_role, response_group
)
SELECT
	professional_role,
	response_group,
	total_responses,
	responses_with_events,
	ROUND(100.0 * responses_with_events / total_responses, 2) AS event_share,
	ROUND(100.0 * first_events_24h / total_responses, 2) AS first_events_24h_share,
	ROUND(median_first_event_hours::numeric, 2) AS median_first_event_hours,
	ROUND(avg_events, 2) AS avg_events,
	ROUND(100.0 * responses_3plus / total_responses, 2) AS share_3plus
FROM group_statistic
ORDER BY professional_role, response_group;
-- В четырех из пяти направлений доля событий у invited ниже; у продуктовых аналитиков — выше.
-- По скорости единой картины нет: у аналитиков данных медиана 65,72 против 54,33 часа,
-- а у разработчиков наоборот 25,83 против 54,73 часа. У дата-инженеров всего 4 invited,
-- поэтому их 144,67 часа по одному событию я бы не использовал для общего вывода.


-- Проверка устойчивости 2: так же сравниваю группы внутри каждого работодателя.
-- У некоторых компаний приглашенных откликов очень мало, поэтому сначала смотрю total_responses.
-- CTE повторяю, чтобы этот запрос можно было выполнить отдельно от проверки по направлениям.
WITH events AS (
	SELECT c.response_id, c.call_at AS event_at
	FROM calls c
	JOIN responses r ON c.response_id = r.response_id
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id
	WHERE c.caller_role = 'employer'
		AND c.call_at >= r.created_at
		AND c.call_at < r.created_at + INTERVAL '7 days'
		AND c.vacancy_id = r.vacancy_id
		AND c.employer_id = v.employer_id
		AND c.applicant_id = r.resume_id

	UNION ALL

	SELECT m.response_id, m.sent_at AS event_at
	FROM messages m
	JOIN responses r ON m.response_id = r.response_id
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id
	WHERE m.sender_role = 'employer'
		AND m.sent_at >= r.created_at
		AND m.sent_at < r.created_at + INTERVAL '7 days'
		AND m.vacancy_id = r.vacancy_id
		AND m.employer_id = v.employer_id
		AND m.applicant_id = r.resume_id
),
event_statistic AS (
	SELECT response_id, COUNT(*) AS total_events, MIN(event_at) AS first_event_at
	FROM events
	GROUP BY response_id
),
response_mart AS (
	SELECT
		e.employer_id,
		e.employer_name,
		CASE WHEN r.status = 'invited' THEN 'invited' ELSE 'other' END AS response_group,
		COALESCE(s.total_events, 0) AS total_events,
		EXTRACT(EPOCH FROM (s.first_event_at - r.created_at)) / 3600
			AS hours_to_first_event
	FROM responses r
	JOIN vacancies v ON r.vacancy_id = v.vacancy_id
	JOIN employers e ON v.employer_id = e.employer_id
	LEFT JOIN event_statistic s ON r.response_id = s.response_id
),
group_statistic AS (
	SELECT
		employer_id,
		employer_name,
		response_group,
		COUNT(*) AS total_responses,
		SUM(CASE WHEN total_events > 0 THEN 1 ELSE 0 END) AS responses_with_events,
		SUM(CASE WHEN hours_to_first_event <= 24 THEN 1 ELSE 0 END) AS first_events_24h,
		PERCENTILE_CONT(0.5) WITHIN GROUP (
			ORDER BY hours_to_first_event
		) AS median_first_event_hours,
		AVG(total_events) AS avg_events,
		SUM(CASE WHEN total_events >= 3 THEN 1 ELSE 0 END) AS responses_3plus
	FROM response_mart
	GROUP BY employer_id, employer_name, response_group
)
SELECT
	employer_id,
	employer_name,
	response_group,
	total_responses,
	responses_with_events,
	ROUND(100.0 * responses_with_events / total_responses, 2) AS event_share,
	ROUND(100.0 * first_events_24h / total_responses, 2) AS first_events_24h_share,
	ROUND(median_first_event_hours::numeric, 2) AS median_first_event_hours,
	ROUND(avg_events, 2) AS avg_events,
	ROUND(100.0 * responses_3plus / total_responses, 2) AS share_3plus
FROM group_statistic
ORDER BY employer_id, response_group;
-- Среди работодателей с 8 и более invited-откликами быстрее первое действие у invited
-- только у 103, 104 и 106; у 101 и 102 оно, наоборот, медленнее.
-- Значит, общие 51,08 против 54,67 часа нельзя переносить на каждого работодателя.
