SELECT DISTINCT id, name, age
FROM users
LEFT OUTER JOIN orders ON id = user_id
WHERE age > 18 AND (active = 1 OR plan != 'free')
GROUP BY id, name, age
ORDER BY name ASC, id DESC
LIMIT 10 OFFSET 5;
