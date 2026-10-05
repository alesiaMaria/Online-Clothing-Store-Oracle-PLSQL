-- =========================================================================
-- 1. Customer loyalty discount system based on order value
-- Description: The store rewards customers with a discount based on order value.
-- Orders > 1000 RON get a 15% discount (new value = 85%), 
-- orders between 500 and 1000 RON get a 10% discount (new value = 90%),
-- and orders < 500 RON get a 5% discount (new value = 95%).
-- Displays order IDs and applied discounts.
-- =========================================================================
DECLARE
  v_id_comanda comenzi.id_comanda%TYPE;
  v_id_max comenzi.id_comanda%TYPE;
  v_id_min comenzi.id_comanda%TYPE;
  v_total_comanda comenzi.total_comanda%TYPE;
  v_status_comanda comenzi.status_comanda%TYPE;
  v_discount NUMBER(3,2);
  v_test NUMBER(2);
  i NUMBER(2);
BEGIN
  SELECT MIN(id_comanda), MAX(id_comanda)
    INTO v_id_min, v_id_max
    FROM comenzi;
    
  FOR i IN v_id_min .. v_id_max
  LOOP
    SELECT COUNT(id_comanda) INTO v_test
    FROM comenzi
    WHERE id_comanda = i;
    
    SELECT status_comanda 
      INTO v_status_comanda
      FROM comenzi
      WHERE id_comanda = i;
      
    IF v_status_comanda = 'PLATITA' THEN
      v_test := 0;
    END IF;
    
    IF v_test = 1 THEN
      SELECT id_comanda, total_comanda INTO v_id_comanda, v_total_comanda 
      FROM comenzi
      WHERE id_comanda = i;
      
      IF v_total_comanda > 1000 THEN
        v_discount := 0.85;
      ELSIF v_total_comanda BETWEEN 500 AND 1000 THEN
        v_discount := 0.90;
      ELSE 
        v_discount := 0.95;
      END IF;
      
      v_total_comanda := v_total_comanda * v_discount;
      
      UPDATE comenzi 
      SET total_comanda = v_total_comanda 
      WHERE id_comanda = v_id_comanda;
      
      COMMIT;
      
      DBMS_OUTPUT.PUT_LINE('Order with ID ' || i || ' received a discount factor of ' || v_discount);
    ELSE
      DBMS_OUTPUT.PUT_LINE('Order with ID ' || i || ' does not exist or has already been paid');
    END IF;
  END LOOP;
END;
/


-- =========================================================================
-- 2. Stock monitoring and replenishment system for low-stock products
-- Description: Counts products whose quantity is below the threshold of 30 units.
-- Updates stock based on specific value brackets and displays variant IDs 
-- along with the added quantities.
-- =========================================================================
DECLARE
  v_prag NUMBER(2) := 30;
  v_id_varianta stocuri.id_varianta%TYPE;
  v_cantitate_disponibila stocuri.cantitate_disponibila%TYPE;
  v_actualizare NUMBER(2);
  v_min stocuri.id_varianta%TYPE;
  v_max stocuri.id_varianta%TYPE;
  i NUMBER(2);
  v_test NUMBER(2);
BEGIN
  SELECT MIN(id_varianta), MAX(id_varianta) 
  INTO v_min, v_max
  FROM stocuri;
  
  i := v_min;
  
  WHILE i <= v_max 
  LOOP
    SELECT COUNT(id_varianta) INTO v_test 
    FROM stocuri 
    WHERE id_varianta = i;
    
    IF v_test = 1 THEN
      SELECT id_varianta, cantitate_disponibila 
      INTO v_id_varianta, v_cantitate_disponibila
      FROM stocuri 
      WHERE id_varianta = i;
      
      IF v_cantitate_disponibila < 30 THEN
        CASE 
          WHEN v_cantitate_disponibila BETWEEN 1 AND 10 THEN v_actualizare := 30;
          WHEN v_cantitate_disponibila BETWEEN 11 AND 20 THEN v_actualizare := 20;
          ELSE v_actualizare := 15;
        END CASE;
      ELSE 
        v_actualizare := 0;
      END IF;
      
      v_cantitate_disponibila := v_cantitate_disponibila + v_actualizare;
      
      UPDATE stocuri 
      SET cantitate_disponibila = v_cantitate_disponibila 
      WHERE id_varianta = i;
      
      COMMIT;
      
      IF v_actualizare = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Product variant ' || i || ' is not below the minimum stock threshold');
      ELSE
        DBMS_OUTPUT.PUT_LINE('Product variant ' || i || ' was updated with ' || v_actualizare || ' units');
      END IF;
    ELSE
      DBMS_OUTPUT.PUT_LINE('Product variant ' || i || ' does not exist'); 
    END IF;
    
    i := i + 1;
  END LOOP;
END;
/


-- =========================================================================
-- 3. Customer classification and ranking report system
-- Description: Places customers into 3 categories based on order count:
-- VIP (over 5 orders), ACTIVE (between 1 and 5 orders), and INACTIV (0 orders).
-- Displays client IDs and their corresponding categories.
-- =========================================================================
DECLARE
  v_id_client clienti.id_client%TYPE;
  v_max clienti.id_client%TYPE;
  v_min clienti.id_client%TYPE;
  v_rang VARCHAR2(10);
  v_nr_comenzi NUMBER(2);
  i NUMBER(2);
  v_test NUMBER(2);
BEGIN
  SELECT MIN(id_client), MAX(id_client)
  INTO v_min, v_max
  FROM clienti;
  
  FOR i IN v_min .. v_max
  LOOP
    SELECT COUNT(id_client) INTO v_test 
    FROM clienti 
    WHERE id_client = i;
    
    IF v_test = 1 THEN
      SELECT COUNT(*) INTO v_nr_comenzi
      FROM comenzi
      WHERE id_client = i;
      
      v_rang := CASE 
                  WHEN v_nr_comenzi > 5 THEN 'VIP'
                  WHEN v_nr_comenzi BETWEEN 1 AND 5 THEN 'ACTIV'
                  ELSE 'INACTIV'
                END;
                
      DBMS_OUTPUT.PUT_LINE('Client ' || i || ' falls into the category ' || v_rang);
    ELSE
      DBMS_OUTPUT.PUT_LINE('Client ' || i || ' does not exist');
    END IF;
  END LOOP;
END;
/


-- =========================================================================
-- 4. Warehouse space clearance and stock-based price reduction system
-- Description: Identifies product variants with high stock to reduce prices:
-- stock > 100 units gets a 30% reduction; stock between 50 and 100 gets 15%;
-- stocks below threshold remain unchanged. Displays modifications.
-- =========================================================================
DECLARE
  v_id_varianta stocuri.id_varianta%TYPE;
  v_cantitate_disponibila stocuri.cantitate_disponibila%TYPE;
  v_pret_lista variante_produs.pret_lista%TYPE;
  v_max stocuri.id_varianta%TYPE;
  v_min stocuri.id_varianta%TYPE;
  v_reducere NUMBER;
  v_test NUMBER;
  i NUMBER;
BEGIN
  SELECT MAX(id_varianta), MIN(id_varianta)
  INTO v_max, v_min 
  FROM stocuri;
  
  FOR i IN v_min .. v_max
  LOOP
    SELECT COUNT(id_varianta) INTO v_test 
    FROM stocuri 
    WHERE id_varianta = i;
    
    IF v_test > 0 THEN
      SELECT id_varianta, cantitate_disponibila
      INTO v_id_varianta, v_cantitate_disponibila 
      FROM stocuri 
      WHERE id_varianta = i;
      
      v_reducere := CASE 
                      WHEN v_cantitate_disponibila > 100 THEN 0.30
                      WHEN v_cantitate_disponibila BETWEEN 50 AND 100 THEN 0.15
                      ELSE 0
                    END;
                    
      IF v_reducere = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Product variant ' || i || ' has low stock. No reduction applied.');
      ELSE
        SELECT pret_lista INTO v_pret_lista 
        FROM variante_produs 
        WHERE id_varianta = i;
        
        v_pret_lista := v_pret_lista * (1 - v_reducere);
        
        UPDATE variante_produs 
        SET pret_lista = v_pret_lista
        WHERE id_varianta = i;
        
        DBMS_OUTPUT.PUT_LINE('Product variant ' || i || ' has high stock, so a ' || (v_reducere * 100) || '% reduction was applied to its price.');
      END IF;
    ELSE 
      DBMS_OUTPUT.PUT_LINE('Product variant ' || i || ' does not exist');
    END IF;
  END LOOP;
END;
/


-- =========================================================================
-- 5. Customer reactivation and "comeback" voucher distribution system
-- Description: Targets registered clients who haven't placed orders for more 
-- than 2 years, offering them a comeback voucher. The voucher value is read 
-- dynamically from keyboard input (&voucher_revenire).
-- =========================================================================
DECLARE
  v_id_client clienti.id_client%TYPE;
  v_data_inregistrare clienti.data_inregistrare%TYPE;
  v_nr_comenzi NUMBER;
  v_voucher NUMBER := &voucher_revenire;
  i NUMBER;
  v_max clienti.id_client%TYPE;
  v_min clienti.id_client%TYPE;
  v_test NUMBER;
  v_an_inregistrare NUMBER;
BEGIN
  SELECT MAX(id_client), MIN(id_client) 
  INTO v_max, v_min 
  FROM clienti;
  
  i := v_min;
  
  WHILE i <= v_max
  LOOP
    SELECT COUNT(*) INTO v_test 
    FROM clienti 
    WHERE id_client = i;
    
    IF v_test = 0 THEN
      DBMS_OUTPUT.PUT_LINE('Client ' || i || ' does not exist');
    ELSE 
      SELECT id_client, data_inregistrare 
      INTO v_id_client, v_data_inregistrare 
      FROM clienti 
      WHERE id_client = i;
      
      SELECT COUNT(*) INTO v_nr_comenzi 
      FROM comenzi 
      WHERE id_client = i;
      
      v_an_inregistrare := EXTRACT(YEAR FROM v_data_inregistrare);
      
      IF (EXTRACT(YEAR FROM SYSDATE) - v_an_inregistrare) > 2 AND v_nr_comenzi = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Client ' || i || ' received a comeback voucher of ' || v_voucher || '%');
      ELSE 
        DBMS_OUTPUT.PUT_LINE('Client ' || i || ' is not eligible for the comeback voucher');
      END IF;
    END IF;
    
    i := i + 1;
  END LOOP;
END;
/
