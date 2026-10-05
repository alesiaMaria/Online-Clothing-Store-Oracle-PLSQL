-- =========================================================================
-- Functions
-- =========================================================================

-- 1. Build a function to calculate the total sum of available quantities for all variants (sizes and colors) of a product, identified by its ID.
CREATE OR REPLACE FUNCTION calcul_stoc_total(p_id_produs IN produse.id_produs%TYPE)
RETURN NUMBER
IS
  v_exista NUMBER;
  e_nu_exista EXCEPTION;
  v_total NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_exista 
  FROM produse 
  WHERE id_produs = p_id_produs;
  
  IF v_exista = 0 THEN
    RAISE e_nu_exista;
  ELSE
    SELECT SUM(s.cantitate_disponibila) INTO v_total
    FROM stocuri s
    LEFT JOIN variante_produs vp ON s.id_varianta = vp.id_varianta
    WHERE vp.id_produs = p_id_produs;
    
    RETURN v_total;
  END IF;
EXCEPTION
  WHEN e_nu_exista THEN
    DBMS_OUTPUT.PUT_LINE('The product does not exist in the store.');
    RETURN 0;
END calcul_stoc_total;
/

-- Testing Function 1:
DECLARE
  v_id_produs variante_produs.id_produs%TYPE := &id_produs;
  v_total NUMBER;
BEGIN
  v_total := calcul_stoc_total(v_id_produs);
  DBMS_OUTPUT.PUT_LINE('The total available quantity of product ' || v_id_produs || ' is ' || v_total);
END;
/


-- 2. Realize a function that returns the total value of all orders placed by a client. The client is identified by the function parameter, specifically by email.
CREATE OR REPLACE FUNCTION calcul_valoare_comenzi(p_email IN clienti.email%TYPE)
RETURN NUMBER
IS 
  v_exista NUMBER;
  e_nu_exista EXCEPTION;
  v_total NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_exista 
  FROM clienti 
  WHERE email = p_email;
  
  IF v_exista = 0 THEN
    RAISE e_nu_exista;
  ELSE
    SELECT SUM(total_comanda) INTO v_total 
    FROM comenzi 
    JOIN clienti USING(id_client) 
    WHERE email = p_email;
    
    IF v_total IS NULL THEN
      RETURN 0;
    ELSE 
      RETURN v_total;
    END IF;
  END IF;
EXCEPTION
  WHEN e_nu_exista THEN
    RETURN 0;
END calcul_valoare_comenzi;
/

-- Testing Function 2:
DECLARE
  v_email clienti.email%TYPE := '&email';
  v_total NUMBER;
BEGIN
  v_total := calcul_valoare_comenzi(v_email);
  DBMS_OUTPUT.PUT_LINE('The total value of all orders placed using email ' || v_email || ' is ' || v_total);
END;
/


-- 3. Realize a function that counts a client's inactivity period. Specifically, it calculates the months from the last placed order until the present.
CREATE OR REPLACE FUNCTION luni_inactivitate_clienti(p_id_client IN clienti.id_client%TYPE)
RETURN NUMBER
IS
  v_exista NUMBER;
  v_ultima_data DATE;
  v_luni_inactive NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_exista 
  FROM clienti 
  WHERE id_client = p_id_client;
  
  IF v_exista = 0 THEN
    RETURN 0;
  END IF;
  
  SELECT MAX(data_comanda) INTO v_ultima_data
  FROM comenzi 
  WHERE id_client = p_id_client;
  
  IF v_ultima_data IS NULL THEN 
    RETURN 0;
  END IF;
  
  -- Note: Depending on Oracle version and date precision, using MONTHS_BETWEEN is usually preferred for exact months, 
  -- but retaining the original logic divided by approx days or standard subtraction as provided:
  v_luni_inactive := SYSDATE - v_ultima_data;
  RETURN ROUND(v_luni_inactive / 30); -- Converted difference into approximate months standard representation
END luni_inactivitate_clienti;
/

-- Testing Function 3:
DECLARE
  v_id clienti.id_client%TYPE := &id_client;
  v_luni NUMBER;
BEGIN
  v_luni := luni_inactivitate_clienti(v_id);
  DBMS_OUTPUT.PUT_LINE('Client ' || v_id || ' has an inactivity period of ' || v_luni || ' months.');
END;
/


-- 4. Realize a function that receives a product variant ID and returns a descriptive text about the stock: 
-- if quantity is above the maximum/minimum threshold return 'STOC BUN', if exactly at limit return 'STOC LIMITA', 
-- and if below threshold return 'STOC INSUFICIENT'.
CREATE OR REPLACE FUNCTION verificare_stoc(p_id IN stocuri.id_varianta%TYPE)
RETURN VARCHAR2
IS
  v_prag stocuri.prag_minim%TYPE;
  v_cantitate stocuri.cantitate_disponibila%TYPE;
  v_test NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_test 
  FROM stocuri 
  WHERE id_varianta = p_id;
  
  IF v_test = 0 THEN 
    RETURN '0';
  END IF;
  
  SELECT prag_minim, cantitate_disponibila 
  INTO v_prag, v_cantitate 
  FROM stocuri 
  WHERE id_varianta = p_id;
  
  CASE
    WHEN v_prag < v_cantitate THEN RETURN 'STOC BUN';
    WHEN v_prag = v_cantitate THEN RETURN 'STOC LIMITA';
    ELSE RETURN 'STOC INSUFICIENT';
  END CASE;
END verificare_stoc;
/

-- Testing Function 4:
DECLARE 
  v_id_varianta stocuri.id_varianta%TYPE := &id_varianta;
  v_status VARCHAR2(90);
BEGIN
  v_status := verificare_stoc(v_id_varianta);
  DBMS_OUTPUT.PUT_LINE('The stock level of product variant ' || v_id_varianta || ' is: ' || v_status);
END;
/


-- =========================================================================
-- Procedures 
-- =========================================================================

-- 1. Build a procedure that receives a brand and a percentage as parameters. 
-- The procedure will increase the list price for all product variants belonging to that brand. 
-- Handle the case where the brand does not exist. Call the procedure.
CREATE OR REPLACE PROCEDURE actualizeaza_pret_brand(
  p_brand IN produse.brand%TYPE, 
  p_procent IN NUMBER
)
IS
  v_nr_actualizari NUMBER;
  e_nu_exista EXCEPTION;
BEGIN
  UPDATE variante_produs
  SET pret_lista = pret_lista + pret_lista * p_procent
  WHERE id_produs IN (
      SELECT id_produs 
      FROM produse 
      WHERE brand = p_brand
  );
  
  v_nr_actualizari := SQL%ROWCOUNT;
  
  IF v_nr_actualizari = 0 THEN
    RAISE e_nu_exista;
  ELSE 
    DBMS_OUTPUT.PUT_LINE('Successfully updated ' || v_nr_actualizari || ' product variants.');
  END IF;
EXCEPTION
  WHEN e_nu_exista THEN
    DBMS_OUTPUT.PUT_LINE('The brand ' || p_brand || ' does not exist in our store, or has no product variants.');
END actualizeaza_pret_brand;
/

-- Testing Procedure 1:
-- EXECUTE actualizeaza_pret_brand('BasicWear', 0.15);


-- 2. Realize a procedure that receives order ID, payment method, and amount. 
-- The procedure will insert a record into the payments table and update the order status to 'PLATITA'. 
-- If the paid amount is less than the order total, throw an exception. This simulates a payment.
CREATE OR REPLACE PROCEDURE realizare_plata_comanda(
  p_id_comanda IN plati.id_comanda%TYPE, 
  p_metoda IN plati.metoda%TYPE, 
  p_suma IN plati.suma%TYPE
)
IS
  v_total_comanda comenzi.total_comanda%TYPE;
  e_suma_prea_mica EXCEPTION;
BEGIN
  SELECT total_comanda 
  INTO v_total_comanda 
  FROM comenzi 
  WHERE id_comanda = p_id_comanda;
  
  IF p_suma < v_total_comanda THEN
    RAISE e_suma_prea_mica;
  ELSE
    -- Note: Table name references 'plati' (or 'plati_da' as written in source script, preserved per implementation)
    INSERT INTO plati(id_comanda, data_plata, metoda, suma, status_plata)
    VALUES (p_id_comanda, SYSDATE, p_metoda, p_suma, 'CONFIRMATA');
    
    UPDATE comenzi
    SET status_comanda = 'PLATITA'
    WHERE id_comanda = p_id_comanda;
    
    DBMS_OUTPUT.PUT_LINE('Payment for order ' || p_id_comanda || ' was successfully registered, with a total amount of ' || p_suma || ' lei.');
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Order ' || p_id_comanda || ' does not exist.');
  WHEN e_suma_prea_mica THEN
    DBMS_OUTPUT.PUT_LINE('Insufficient funds. The amount is too small for the full payment of order ' || p_id_comanda);
END realizare_plata_comanda;
/

-- Testing Procedure 2:
-- BEGIN
--   realizare_plata_comanda(1, 'CARD', 200.00);
-- END;
-- /


-- 3. Build a procedure that loops through all stocks. For variants where the quantity is below the minimum threshold, 
-- increase the stock by a value given as a parameter. Display how many variants were updated using an OUT parameter.
CREATE OR REPLACE PROCEDURE actualizare_prag(
  p_prag_minim IN NUMBER, 
  p_valoare IN NUMBER, 
  p_nr_variante OUT NUMBER
)
IS
BEGIN
  UPDATE stocuri
  SET cantitate_disponibila = cantitate_disponibila + p_valoare
  WHERE cantitate_disponibila < p_prag_minim;
  
  p_nr_variante := SQL%ROWCOUNT;
  COMMIT;
END actualizare_prag;
/

-- Testing Procedure 3:
DECLARE
  v_nr_actualizari NUMBER;
BEGIN
  actualizare_prag(40, 30, v_nr_actualizari);
  
  IF v_nr_actualizari = 0 THEN
    DBMS_OUTPUT.PUT_LINE('0 updates performed. All products have stock above the given minimum threshold.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Performed ' || v_nr_actualizari || ' stock updates.');
  END IF;
END;
/


-- 4. Realize a procedure that receives a product variant's price and modifies it by applying a voucher, as follows: 
-- if price is above 500 lei the voucher is 20%, if between 100-500 the voucher is 15%, otherwise price remains the same. 
-- The price is returned through the same parameter (IN OUT).
CREATE OR REPLACE PROCEDURE adauga_voucher(
  p_id_varianta IN variante_produs.id_varianta%TYPE, 
  p_pret_final IN OUT variante_produs.pret_lista%TYPE
)
IS 
  v_discount NUMBER;
  e_nu_este_valid EXCEPTION;
BEGIN
  IF p_pret_final <= 0 THEN
    RAISE e_nu_este_valid;
  END IF;
  
  v_discount := CASE 
                  WHEN p_pret_final > 500 THEN 0.20
                  WHEN p_pret_final BETWEEN 100 AND 500 THEN 0.15
                  ELSE 0
                END;
                
  p_pret_final := p_pret_final + (p_pret_final * v_discount);
  DBMS_OUTPUT.PUT_LINE('Discount of ' || (v_discount * 100) || '% was successfully applied.');
EXCEPTION 
  WHEN e_nu_este_valid THEN
    DBMS_OUTPUT.PUT_LINE('Price must be a positive number and different from zero.');
END adauga_voucher;
/

-- Testing Procedure 4:
DECLARE
  v_id_varianta variante_produs.id_varianta%TYPE := &id_varianta;
  v_pret variante_produs.pret_lista%TYPE;
BEGIN
  SELECT pret_lista 
  INTO v_pret 
  FROM variante_produs 
  WHERE id_varianta = v_id_varianta;
  
  DBMS_OUTPUT.PUT_LINE('Initial price is: ' || v_pret);
  adauga_voucher(v_id_varianta, v_pret);
  DBMS_OUTPUT.PUT_LINE('Price after applying the discount is: ' || v_pret);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Product variant ' || v_id_varianta || ' does not exist.');
END;
/
