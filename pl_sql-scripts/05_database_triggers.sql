-- =========================================================================
-- Triggers 
-- =========================================================================

-- 1. Create a trigger that evaluates each insert on the payments table. 
-- It must not allow paying an order that already has the 'PLATITA' status. 
-- Additionally, it will not allow payment through an amount too small or too large compared to the order total.
CREATE OR REPLACE TRIGGER verifica_plata
BEFORE INSERT ON plati
FOR EACH ROW
DECLARE
  v_total comenzi.total_comanda%TYPE;
  v_status comenzi.status_comanda%TYPE;
BEGIN
  DBMS_OUTPUT.PUT_LINE('The trigger has executed.');
  
  SELECT total_comanda, status_comanda 
  INTO v_total, v_status 
  FROM comenzi 
  WHERE id_comanda = :new.id_comanda;
  
  IF UPPER(v_status) = 'PLATITA' THEN
    RAISE_APPLICATION_ERROR(-20001, 'Cannot pay for an order that has already been paid previously.');
  END IF;
  
  IF :new.suma < v_total OR :new.suma > v_total THEN
    RAISE_APPLICATION_ERROR(-20004, 'Cannot pay for an order with an amount lower or higher than the order value.');
  END IF;
END;
/

-- Testing Trigger 1:
-- a. Attempting a payment on an already paid order:
-- INSERT INTO plati(id_plata, id_comanda, data_plata, metoda, suma, status_plata)
-- VALUES(11, 1, SYSDATE, 'online', 149.99, 'Bucuresti');

-- b. Attempting a payment with an amount that is too large:
-- INSERT INTO plati(id_plata, id_comanda, data_plata, metoda, suma, status_plata)
-- VALUES(11, 4, SYSDATE, 'online', 150, 'Bucuresti');


-- 2. Create a trigger on the clients table that will forbid updating the address if the respective client has active orders. 
-- Thus, the integrity of the order delivery address is preserved.
CREATE OR REPLACE TRIGGER restrictie_adresa
BEFORE UPDATE OF adresa
ON clienti
FOR EACH ROW
DECLARE
  v_nr_comenzi_active NUMBER;
BEGIN
  SELECT COUNT(*) 
  INTO v_nr_comenzi_active
  FROM comenzi
  WHERE id_client = :old.id_client 
    AND UPPER(status_comanda) <> 'LIVRATA';
  
  IF v_nr_comenzi_active > 0 THEN
    RAISE_APPLICATION_ERROR(-20001, 'Updating the address is not permitted as long as the client has active orders.');
  END IF;
END;
/

-- Testing Trigger 2:
-- a. Updating a client who has active orders:
-- UPDATE clienti
-- SET adresa = 'Constanta'
-- WHERE id_client = 4;

-- b. Updating a client who does not have active orders:
-- UPDATE clienti
-- SET adresa = 'Brasov'
-- WHERE id_client = 8;


-- 3. Create a trigger that, after any insert into the product variants table, automatically adds a record to the stock table. 
-- For id_stoc, it retrieves the maximum from the table and increments it by 1, and for quantity and minimum threshold, uses generic values (200 and 40).
CREATE OR REPLACE TRIGGER adauga_stoc
AFTER INSERT ON variante_produs
FOR EACH ROW
DECLARE
  v_id_max stocuri.id_stoc%TYPE;
BEGIN
  SELECT MAX(id_stoc) 
  INTO v_id_max 
  FROM stocuri;
  
  INSERT INTO stocuri(id_stoc, id_varianta, cantitate_disponibila, prag_minim, ultima_actualizare)
  VALUES (v_id_max + 1, :new.id_varianta, 200, 40, SYSDATE);
END;
/

-- Testing Trigger 3:
-- INSERT INTO variante_produs(id_varianta, id_produs, marime, culoare, cod_produs_ales, pret_lista)
-- VALUES(11, 10, 'XS', 'Roz', 'RCH-XS-ROZ', 130.45);


-- 4. Create a trigger that automatically generates a product variant code (cod_produs_ales) for any new insert on the product variants table 
-- if it is not mentioned. General format: (PRD-SIZE-COLOR).
CREATE OR REPLACE TRIGGER generare_cod
BEFORE INSERT ON variante_produs
FOR EACH ROW
DECLARE
  v_cod VARCHAR2(20);
BEGIN
  v_cod := 'PRD-' || UPPER(:new.marime) || '-' || UPPER(:new.culoare);
  :new.cod_produs_ales := v_cod;
END;
/

-- Testing Trigger 4:
-- INSERT INTO variante_produs(id_varianta, id_produs, marime, culoare, pret_lista)
-- VALUES (12, 10, 'Negru', 'M', 178.99);
