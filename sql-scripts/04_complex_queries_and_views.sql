-- 5.1 Display all active products containing the sequence "roch" in their name, along with their category, ordered alphabetically by category and product
SELECT p.id_produs, p.denumire, c.denumire AS categorie, p.brand  
FROM produse p 
JOIN categorii c 
ON c.id_categorie = p.id_categorie  
WHERE p.activ = 'Y'  
AND LOWER(p.denumire) LIKE '%roch%'  
ORDER BY c.denumire, p.denumire;

-- 5.2 Display product variants whose prices fall within a given range (between 100 and 400 lei), ordered descending by price
SELECT v.cod_produs_ales, v.marime, v.culoare, v.pret_lista  
FROM variante_produs v 
WHERE v.pret_lista BETWEEN 100 AND 400 
ORDER BY v.pret_lista DESC;

-- 5.3 Display product variants with stock below the minimum threshold, explicitly marking stock depletion risk alert situations
-- Note: No products with stock below the minimum threshold were identified during the query, indicating proper stock management.
SELECT v.cod_produs_ales, s.cantitate_disponibila, s.prag_minim,  
CASE 
WHEN s.cantitate_disponibila < s.prag_minim THEN 'ALERTA' ELSE 'OK' END AS 
status_stoc  
FROM stocuri s 
JOIN variante_produs v 
ON v.id_varianta = s.id_varianta  
WHERE s.cantitate_disponibila < s.prag_minim;

-- 5.4 Identify clients who have not placed any orders to date
-- Note: No clients without orders were identified, indicating that all existing clients are active.
SELECT cl.id_client, cl.nume, cl.prenume, cl.email  
FROM clienti cl 
LEFT JOIN comenzi co ON co.id_client = cl.id_client  
WHERE co.id_comanda IS NULL;

-- 5.5 Display orders placed in the last 7 days, ordered descending by the order date
SELECT id_comanda, id_client, data_comanda, status_comanda, total_comanda  
FROM comenzi  
WHERE data_comanda >= SYSDATE - 7  
ORDER BY data_comanda DESC;

-- 5.6 Display orders placed within a specified time range, using explicit conversion of calendar dates
SELECT id_comanda, data_comanda, total_comanda FROM comenzi  
WHERE data_comanda BETWEEN TO_DATE('2026-01-01','YYYY-MM-DD') AND 
TO_DATE('2026-12-31','YYYY-MM-DD') 
ORDER BY data_comanda;

-- 5.7 Display orders placed on the same calendar day as the current date, highlighting the day type (today / other day) and order value
SELECT id_comanda, total_comanda, data_comanda, 
CASE  
WHEN TRUNC(data_comanda) = TRUNC(SYSDATE)  
THEN 'COMANDA ASTAZI' ELSE 'ALTA ZI' END AS TIP_ZI FROM comenzi  
WHERE TRUNC(data_comanda) = TRUNC(SYSDATE);

-- 5.8 Analyze orders per status, displaying only statuses with at least two associated orders
SELECT status_comanda, 
COUNT(*) AS nr_comenzi, SUM(total_comanda) AS valoare_totala  
FROM comenzi  
GROUP BY status_comanda  
HAVING COUNT(*) >= 2 ORDER BY valoare_totala DESC;

-- 5.9 Analyze payments made, grouped by payment method, using descriptive labels for each method type
SELECT DECODE(metoda, 'CARD','Plată cu card', 'RAMBURS','Ramburs', 
'TRANSFER','Transfer bancar', 'Altă metodă') AS metoda_descriere, 
COUNT(*) AS nr_plati, SUM(suma) AS total_incasari FROM plati  
GROUP BY metoda  
ORDER BY total_incasari DESC;

-- 5.10 Display order evolution by months and years, highlighting the number of orders and total value for each period
SELECT EXTRACT(YEAR FROM data_comanda) AS an, EXTRACT(MONTH FROM 
data_comanda) AS luna, COUNT(*) AS nr_comenzi, SUM(total_comanda) AS total 
FROM comenzi  
GROUP BY EXTRACT(YEAR FROM data_comanda), EXTRACT(MONTH FROM 
data_comanda)  
ORDER BY an, luna;

-- 5.11 Display the client list, partially masking the email address for personal data protection
SELECT id_client, nume, prenume, SUBSTR(email, 1, 3) || '**' || SUBSTR(email, 
INSTR(email,'@')) AS email_mascat  
FROM clienti;

-- 5.12 Display clients along with their city of residence, replacing missing values with the mention "NEPRECIZAT"
SELECT id_client, nume, prenume, NVL(oras, 'NEPRECIZAT') AS oras_afisat 
FROM clienti;

-- 5.13 Display high-value orders (at least 200 lei) that are not cancelled and belong to valid statuses
SELECT id_comanda, total_comanda, status_comanda  
FROM comenzi  
WHERE total_comanda >= 200 AND status_comanda != 'ANULATA' AND status_comanda IN 
('NOUA','PLATITA','LIVRATA','RETURNATA','IN_PROCESARE');

-- 5.14 Identify products that do not yet have product variants defined
SELECT p.id_produs, p.denumire  
FROM produse p 
WHERE NOT EXISTS ( SELECT 1 FROM variante_produs v  
WHERE v.id_produs = p.id_produs );

-- 5.15 Display product variants that are out of stock
SELECT v.cod_produs_ales, s.cantitate_disponibila  
FROM variante_produs v 
JOIN stocuri s ON s.id_varianta = v.id_varianta  
WHERE s.cantitate_disponibila = 0;

-- 5.16 Display the list of clients from Bucharest, as well as clients who have placed at least one order with a value greater than 300 lei
SELECT cl.id_client, cl.nume, cl.prenume, 'Bucuresti' AS motiv  
FROM clienti cl 
WHERE cl.oras = 'București' 
UNION 
SELECT DISTINCT cl.id_client, cl.nume, cl.prenume, 'Comanda > 300' AS motiv 
FROM clienti cl  
JOIN comenzi co ON co.id_client = cl.id_client 
WHERE co.total_comanda > 300;

-- 5.17 Identify clients who have placed orders, but for whom there is no confirmed payment associated with their orders
SELECT DISTINCT cl.id_client, cl.nume, cl.prenume 
FROM clienti cl  
WHERE EXISTS ( SELECT 1 FROM comenzi co WHERE co.id_client = cl.id_client ) AND 
NOT EXISTS ( SELECT 1 FROM comenzi co JOIN plati p ON p.id_comanda = co.id_comanda 
WHERE co.id_client = cl.id_client AND p.status_plata = 'CONFIRMATA' );

-- 5.18 Identify clients who have placed orders, but for whom there is no associated confirmed payment (using MINUS)
SELECT DISTINCT id_client  
FROM comenzi  
MINUS 
SELECT DISTINCT co.id_client FROM comenzi co JOIN plati p ON p.id_comanda = 
co.id_comanda  
WHERE p.status_plata = 'CONFIRMATA';

-- 5.19 Display clients who are from Bucharest and have placed at least one order
SELECT id_client  
FROM clienti  
WHERE oras = 'București' 
INTERSECT  
SELECT DISTINCT id_client  
FROM comenzi;

-- 5.20 Display the hierarchical structure of product categories, highlighting hierarchy levels and the complete path of each category
SELECT LEVEL AS nivel, denumire AS categorie, SYS_CONNECT_BY_PATH(denumire, ' > 
') AS cale 
FROM categorii  
START WITH id_parinte IS NULL 
CONNECT BY PRIOR id_categorie = id_parinte  
ORDER BY cale;

-- 5.21 Display orders along with the customer's full name, order value, and an indicator showing whether it is recent (placed in the last 7 days) or older
SELECT c.id_comanda, cl.nume || ' ' || cl.prenume AS client, c.total_comanda, c.data_comanda, 
CASE  
WHEN c.data_comanda >= SYSDATE - 7  
THEN 'RECENTA' ELSE 'VECHE' END AS tip_comanda  
FROM comenzi c  
JOIN clienti cl ON c.id_client = cl.id_client;

-- 5.22 Display products and their variants that have the available quantity below the established minimum threshold, to identify depletion-risk products
SELECT p.denumire AS produs, v.cod_produs_ales, s.cantitate_disponibila, s.prag_minim 
FROM stocuri s  
JOIN variante_produs v  
ON s.id_varianta = v.id_varianta  
JOIN produse p ON v.id_produs = p.id_produs  
WHERE s.cantitate_disponibila < s.prag_minim;

-- 5.23 Calculate the total order value per month for delivered orders, keeping only months where the total exceeds 300
SELECT TO_CHAR(c.data_comanda, 'YYYY-MM') AS luna, SUM(c.total_comanda) AS 
valoare_totala  
FROM comenzi c  
WHERE c.status_comanda = 'LIVRATA' 
GROUP BY TO_CHAR(c.data_comanda, 'YYYY-MM') HAVING SUM(c.total_comanda) > 
300 
ORDER BY luna;

-- 5.24 Create a sequence for automatic product variant code generation and use it in a controlled insertion
CREATE SEQUENCE seq_cod_variant START WITH 1 INCREMENT BY 1 NOCACHE; 

INSERT INTO variante_produs (id_produs, marime, culoare, cod_produs_ales, pret_lista) 
SELECT p.id_produs, 'M', 'Negru', 'AUTO-' || TO_CHAR(seq_cod_variant.NEXTVAL), 199.99 
FROM produse p  
WHERE p.activ = 'Y' AND p.id_produs = (SELECT MIN(id_produs) FROM produse WHERE 
activ = 'Y');

-- 5.25 Create a virtual table (VIEW) containing synthesized order information with customer data, and query orders with value >= 200 lei
CREATE OR REPLACE VIEW V_RAPORT_COMENZI AS 
SELECT c.id_comanda, c.data_comanda, c.status_comanda, c.total_comanda, cl.nume || ' ' || cl.prenume AS client  
FROM comenzi c JOIN clienti cl ON cl.id_client = c.id_client; 

SELECT * FROM V_RAPORT_COMENZI WHERE total_comanda >= 200;

-- 5.26 Create a synonym for the clients table and query through the synonym
CREATE OR REPLACE SYNONYM syn_clienti FOR clienti; 

SELECT id_client, nume, prenume, email FROM syn_clienti ORDER BY id_client;

-- 5.27 Display clients whose total order amount is greater than or equal to the average total per client
SELECT cl.id_client, cl.nume, cl.prenume, SUM(c.total_comanda) AS total_cheltuit  
FROM clienti cl  
JOIN comenzi c ON c.id_client = cl.id_client  
GROUP BY cl.id_client, cl.nume, cl.prenume HAVING SUM(c.total_comanda) >= ( SELECT 
AVG(total_pe_client)  
FROM ( SELECT SUM(c2.total_comanda) AS total_pe_client FROM comenzi c2  
GROUP BY c2.id_client ) ) 
ORDER BY total_cheltuit DESC;

-- 5.28 Display all product variants, showing 0 for quantity and -1 for threshold if there is no stock record
SELECT p.denumire AS produs, v.cod_produs_ales, NVL(s.cantitate_disponibila, 0) AS 
cantitate_disponibila, NVL(s.prag_minim, -1) AS prag_minim  
FROM variante_produs v 
JOIN produse p ON p.id_produs = v.id_produs LEFT JOIN stocuri s ON s.id_varianta = 
v.id_varianta  
ORDER BY p.denumire, v.cod_produs_ales;

-- 5.29 Display the date of the last order and its value (if any) for each client
SELECT cl.id_client, cl.nume, cl.prenume, 
(SELECT MAX(c.data_comanda) FROM comenzi c WHERE c.id_client = cl.id_client) AS data_ultima_comanda, 
(SELECT MAX(c.total_comanda) FROM comenzi c WHERE c.id_client = cl.id_client AND c.data_comanda = 
(SELECT MAX(c2.data_comanda) FROM comenzi c2 WHERE c2.id_client = cl.id_client)) AS valoare_ultima_comanda  
FROM clienti cl  
ORDER BY cl.id_client;

-- 5.30 Display orders and a time interval category (Morning / Afternoon / Evening) based on the order time
SELECT id_comanda, TO_CHAR(data_comanda, 'YYYY-MM-DD HH24:MI') AS 
data_formatata, total_comanda,  
CASE 
WHEN TO_NUMBER(TO_CHAR(data_comanda, 'HH24')) BETWEEN 6 AND 11 THEN 
'DIMINEATA'  
WHEN TO_NUMBER(TO_CHAR(data_comanda, 'HH24')) BETWEEN 12 AND 17 THEN 
'DUPA-AMIAZA' ELSE 'SEARA'  
END AS interval_orar 
FROM comenzi  
ORDER BY data_comanda DESC;

-- 5.31 Create an index for frequent filters by status and method, then display confirmed card payments
CREATE INDEX idx_plati_status_metoda ON plati (status_plata, metoda); 

SELECT id_plata, id_comanda, data_plata, metoda, suma, status_plata  
FROM plati 
WHERE status_plata = 'CONFIRMATA' AND metoda = 'CARD' ORDER BY data_plata 
DESC;
