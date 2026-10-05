-- a. Register a new order for the client “Dorcea Alesia_Maria” with the status “NOUA”

INSERT INTO comenzi 
(id_client, data_comanda, status_comanda, total_comanda, adresa_livrare) 
SELECT id_client, SYSDATE, 'NOUA', 239.99, 'Bucuresti, Aleea Barajul Dunarii' 
FROM clienti 
WHERE email = 'dorceaalesia24@stud.ase.ro';

-- b. Update the total_comanda value for new orders by adding the price of the product variant ‘RCB-M-ROS’, in order to simulate adding 
a product in the shopping cart.
  
UPDATE comenzi c 
SET c.total_comanda = c.total_comanda + 
( 
    SELECT v.pret_lista 
    FROM variante_produs v 
    WHERE v.cod_produs_ales = 'RCB-M-ROS' 
) 
WHERE c.status_comanda = 'NOUA' 
AND EXISTS ( 
    SELECT 1 
    FROM variante_produs v 
    WHERE v.cod_produs_ales = 'RCB-M-ROS' 
);

-- c. Reduce the stock of the ordered product by the quantity sold

UPDATE stocuri s 
SET cantitate_disponibila = cantitate_disponibila - 1 
WHERE id_varianta IN ( 
    SELECT id_varianta 
    FROM variante_produs 
    WHERE cod_produs_ales = 'RCB-M-ROS' 
);

-- d. Update the order status from “NOUA” to “PLATITA” only if there is a confirmed payment associated

UPDATE comenzi c 
SET c.status_comanda = 'PLATITA' 
WHERE c.status_comanda = 'NOUA' 
AND EXISTS ( 
    SELECT 1 
    FROM plati p 
    WHERE p.id_comanda = c.id_comanda 
    AND p.status_plata = 'CONFIRMATA'
);

-- e. Insert “INITIATA” payments for “NOUA” orders that do not yet have any payment

INSERT INTO plati (id_comanda, data_plata, metoda, suma, status_plata) 
SELECT c.id_comanda, SYSDATE, 
    CASE 
        WHEN c.total_comanda >= 200 THEN 'TRANSFER' 
        ELSE 'CARD' 
    END AS METODA, 
    c.total_comanda, 
    'INITIATA' 
FROM comenzi c 
WHERE c.status_comanda = 'NOUA' 
AND NOT EXISTS ( 
    SELECT 1 
    FROM plati p 
    WHERE p.id_comanda = c.id_comanda
);

-- f. Mark as delivered the paid orders placed at least one day ago with a confirmed payment

UPDATE comenzi c 
SET c.status_comanda = 'LIVRATA' 
WHERE c.status_comanda = 'PLATITA' 
AND c.data_comanda <= SYSDATE - 1 
AND EXISTS ( 
    SELECT 1 
    FROM plati p 
    WHERE p.id_comanda = c.id_comanda 
    AND p.status_plata = 'CONFIRMATA' 
);

-- g. Update the minimum threshold in the stock table based on available quantity rules

UPDATE stocuri s 
SET prag_minim = 
    CASE 
        WHEN s.cantitate_disponibila < 10 THEN 5 
        WHEN s.cantitate_disponibila BETWEEN 10 AND 30 THEN 3 
        ELSE 2 
    END, 
    ultima_actualizare = SYSDATE 
WHERE s.prag_minim <> 
    CASE 
        WHEN s.cantitate_disponibila < 10 THEN 5 
        WHEN s.cantitate_disponibila BETWEEN 10 AND 30 THEN 3 
        ELSE 2 
    END; 

COMMIT;

-- h. Add a new product to the category “Rochii elegante” only if a product with the same name does not already exist

INSERT INTO produse (id_categorie, denumire, brand, descriere, activ) 
SELECT c.id_categorie, 
       'Rochie seara satin', 
       'Elegance', 
       'Rochie lunga eleganta', 
       'Y' 
FROM categorii c 
WHERE c.denumire = 'Rochii_elegante' 
AND NOT EXISTS ( 
    SELECT 1 
    FROM produse p 
    WHERE p.id_categorie = c.id_categorie 
    AND UPPER(p.denumire) = UPPER('Rochie seara satin') 
);

-- i. Add a variant for the product “Rochie seara satin” only if the product exists and the code is not already in use

INSERT INTO variante_produs (id_produs, marime, culoare, cod_produs_ales, pret_lista) 
SELECT p.id_produs, 'M', 'Negru', 'RS-M-NEGRU', 399.99 
FROM produse p 
WHERE p.denumire = 'Rochie seara satin' 
AND NOT EXISTS ( 
    SELECT 1 
    FROM variante_produs v 
    WHERE v.cod_produs_ales = 'RS-M-NEGRU'
);

-- j. Insert initial stock for the variant “RS-M-NEGRU” only if no record already exists in stock

INSERT INTO stocuri (id_varianta, cantitate_disponibila, prag_minim, ultima_actualizare) 
SELECT v.id_varianta, 15, 3, SYSDATE 
FROM variante_produs v 
WHERE v.cod_produs_ales = 'RS-M-NEGRU' 
AND NOT EXISTS ( 
    SELECT 1 
    FROM stocuri s 
    WHERE s.id_varianta = v.id_varianta 
);

-- k. Delete cancelled orders whose payment was not confirmed 

DELETE FROM plati p 
WHERE p.status_plata <> 'CONFIRMATA' 
AND EXISTS ( 
    SELECT 1 
    FROM comenzi c 
    WHERE c.id_comanda = p.id_comanda 
    AND c.status_comanda = 'ANULATA' 
); 

DELETE FROM comenzi 
WHERE status_comanda = 'ANULATA';

-- l. Delete failed payments older than 30 days

DELETE FROM plati 
WHERE status_plata = 'ESUATA' 
AND data_plata < SYSDATE - 30;

-- m. Reduce the price by 10% for products with stock below the minimum threshold

UPDATE variante_produs 
SET pret_lista = pret_lista * 0.9 
WHERE id_varianta IN ( 
    SELECT id_varianta 
    FROM stocuri 
    WHERE cantitate_disponibila < prag_minim
);

-- n. Update the payment if it exists or insert it if it does not exist

MERGE INTO plati p 
USING comenzi c 
ON (p.id_comanda = c.id_comanda) 
WHEN MATCHED THEN 
    UPDATE SET p.status_plata = 'CONFIRMATA' 
WHEN NOT MATCHED THEN 
    INSERT (id_comanda, data_plata, metoda, suma, status_plata) 
    VALUES (c.id_comanda, SYSDATE, 'CARD', c.total_comanda, 'CONFIRMATA');
