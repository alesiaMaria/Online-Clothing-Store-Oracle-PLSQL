-- =========================================================================
-- A. Implicit Cursors
-- =========================================================================

-- 1. The store receives a shipment for all variants of a product. Increase the stock for each variant by 50 units and display how many variants were updated.
DECLARE
  v_id_produs produse.id_produs%TYPE := &id_produs;
BEGIN
  UPDATE stocuri
  SET cantitate_disponibila = cantitate_disponibila + 50, 
      ultima_actualizare = SYSDATE
  WHERE id_varianta IN (
      SELECT id_varianta 
      FROM variante_produs 
      WHERE id_produs = v_id_produs
  );
  
  IF SQL%FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Successfully updated ' || SQL%ROWCOUNT || ' product variants.');
  ELSE 
    DBMS_OUTPUT.PUT_LINE('No product variants found to update for product ID ' || v_id_produs);
  END IF;
END;
/


-- 2. The system aims to clean up failed payment history. Confirm if a deletion occurred, and if there were multiple, return their count.
DECLARE
  v_status_cautat VARCHAR2(20) := 'ESUATA';
BEGIN
  DELETE FROM plati
  WHERE status_plata = v_status_cautat;
  
  IF SQL%FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Successfully deleted ' || SQL%ROWCOUNT || ' payments.');
  ELSE 
    DBMS_OUTPUT.PUT_LINE('No failed payments exist in the table.');
  END IF;
END;
/


-- 3. Due to inflation, the prices of all product variants in a certain category increase by 10%. Highlight whether this affected the store's database.
DECLARE
  v_id_categorie produse.id_categorie%TYPE := &id_categorie;
BEGIN
  UPDATE variante_produs
  SET pret_lista = pret_lista * 1.1
  WHERE id_produs IN (
      SELECT id_produs 
      FROM produse 
      WHERE id_categorie = v_id_categorie
  );
  
  IF SQL%NOTFOUND THEN
    DBMS_OUTPUT.PUT_LINE('No products found to update in category ' || v_id_categorie);
  ELSIF SQL%FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Updated ' || SQL%ROWCOUNT || ' products from category ' || v_id_categorie || '.');
  END IF;
END;
/



-- =========================================================================
-- B. Explicit Cursors
-- =========================================================================

-- 1. Create a report of the store's best-selling products whose available quantity is below 40 units.
DECLARE
  v_id_produs variante_produs.id_produs%TYPE;
  v_marime variante_produs.marime%TYPE;
  v_culoare variante_produs.culoare%TYPE;
  v_cod_produs_ales variante_produs.cod_produs_ales%TYPE;
  v_pret_lista variante_produs.pret_lista%TYPE;
  v_cantitate stocuri.cantitate_disponibila%TYPE;
  
  CURSOR c_prod IS 
    SELECT id_produs, marime, culoare, cod_produs_ales, pret_lista, cantitate_disponibila 
    FROM variante_produs 
    JOIN stocuri USING(id_varianta);
BEGIN
  OPEN c_prod;
  DBMS_OUTPUT.PUT_LINE('REPORT - BEST SELLING PRODUCTS (LOW STOCK):');
  LOOP
    FETCH c_prod INTO v_id_produs, v_marime, v_culoare, v_cod_produs_ales, v_pret_lista, v_cantitate;
    EXIT WHEN c_prod%NOTFOUND;
    
    IF v_cantitate < 40 THEN
      DBMS_OUTPUT.PUT_LINE('Product ' || v_id_produs || ' has size ' || v_marime || ' and color ' || v_culoare || ', code: ' || v_cod_produs_ales || ', price: ' || v_pret_lista);
    END IF;
  END LOOP;
  CLOSE c_prod;
END;
/


-- 2. Apply a 15% price reduction to all products belonging to a specific brand entered from the keyboard.
DECLARE
  v_brand produse.brand%TYPE := '&brand';
  CURSOR c_prod IS 
    SELECT id_varianta, brand 
    FROM variante_produs 
    JOIN produse USING(id_produs);
  v_c c_prod%ROWTYPE;
BEGIN
  OPEN c_prod;
  LOOP
    FETCH c_prod INTO v_c;
    EXIT WHEN c_prod%NOTFOUND;
    
    IF v_c.brand = v_brand THEN
      UPDATE variante_produs
      SET pret_lista = pret_lista * (1 - 0.15)
      WHERE id_varianta = v_c.id_varianta;
      
      DBMS_OUTPUT.PUT_LINE('Product variant ' || v_c.id_varianta || ' belonging to brand ' || v_c.brand || ' was reduced by 15%.');
    END IF;
  END LOOP;
  CLOSE c_prod;
END;
/


-- 3. Format a list of all registered clients on the store's website for a given year entered from the keyboard.
DECLARE
  v_an NUMBER := &an_inregistrare;
  CURSOR c_cl IS 
    SELECT id_client, nume || ' ' || prenume AS nume_complet, data_inregistrare 
    FROM clienti;
  v_contor NUMBER := 0;
BEGIN
  DBMS_OUTPUT.PUT_LINE('Clients registered in the year ' || v_an || ':');
  FOR v_c IN c_cl
  LOOP
    IF EXTRACT(YEAR FROM v_c.data_inregistrare) = v_an THEN
      v_contor := v_contor + 1;
      DBMS_OUTPUT.PUT_LINE('Client ID ' || v_c.id_client || ', Name: ' || v_c.nume_complet);
    END IF;
  END LOOP;
  
  IF v_contor = 0 THEN
    DBMS_OUTPUT.PUT_LINE('No clients registered in the given year.');
  END IF;
END;
/


-- 4. Build an algorithm to sort clients based on their cities of residence, where cities are grouped alphabetically.
DECLARE
  v_litera CHAR(1) := '&litera_mare';
  CURSOR c_cl(p_litera CHAR) IS 
    SELECT id_client, nume || ' ' || prenume AS nume_complet, oras 
    FROM clienti 
    WHERE UPPER(oras) LIKE UPPER(p_litera) || '%';
  v_contor NUMBER := 0;
BEGIN
  DBMS_OUTPUT.PUT_LINE('Clients from cities starting with letter: ' || v_litera);
  FOR v_cl IN c_cl(v_litera)
  LOOP
    v_contor := v_contor + 1;
    DBMS_OUTPUT.PUT_LINE('Client ' || v_cl.id_client || ' : ' || v_cl.nume_complet);
  END LOOP;
  
  IF v_contor = 0 THEN
    DBMS_OUTPUT.PUT_LINE('No clients from cities starting with letter ' || v_litera);
  END IF;
END;
/


-- 5. Manage store inventory by grouping products into categories.
DECLARE
  CURSOR c_cat IS 
    SELECT id_categorie, denumire 
    FROM categorii;
  CURSOR c_prod(p_id NUMBER) IS 
    SELECT id_produs, denumire 
    FROM produse 
    WHERE id_categorie = p_id;
BEGIN
  FOR v_cat IN c_cat
  LOOP
    DBMS_OUTPUT.PUT_LINE('Category ' || v_cat.id_categorie || ' : ' || v_cat.denumire || ' contains products:');
    FOR v_prod IN c_prod(v_cat.id_categorie)
    LOOP
      DBMS_OUTPUT.PUT_LINE('  Product ' || v_prod.id_produs || ' -- ' || v_prod.denumire);
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------');
  END LOOP;
END;
/



-- =========================================================================
-- EXCEPTIONS
-- =========================================================================

-- A. Implicit Exceptions

-- 1. Automatically return the price of a product based solely on the variant ID. Handle the case where the variant does not exist.
DECLARE
  v_id_varianta variante_produs.id_varianta%TYPE := &id_produs;
  v_pret_lista variante_produs.pret_lista%TYPE;
BEGIN
  SELECT pret_lista 
  INTO v_pret_lista 
  FROM variante_produs 
  WHERE id_varianta = v_id_varianta;
  
  DBMS_OUTPUT.PUT_LINE('Price: ' || v_pret_lista);
EXCEPTION 
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Product variant ' || v_id_varianta || ' does not exist.');
END;
/



-- 2. The store wants to implement an algorithm that will search the site's database for a client by their name. Handle the case where multiple clients share the same name.

DECLARE
  v_prenume clienti.prenume%TYPE := '&nume_client';
  v_data_inreg clienti.data_inregistrare%TYPE;
  v_email clienti.email%TYPE;
BEGIN
  SELECT data_inregistrare, email 
  INTO v_data_inreg, v_email 
  FROM clienti 
  WHERE UPPER(prenume) LIKE UPPER(v_prenume);
  
EXCEPTION
  WHEN TOO_MANY_ROWS THEN
    DBMS_OUTPUT.PUT_LINE('There are multiple clients with the first name ' || v_prenume);
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('No client exists with the first name ' || v_prenume);
END;
/

-- 3. The store wants to display all product variants along with a description and their price. Handle exceptions accordingly.

DECLARE
  CURSOR c IS 
    SELECT id_varianta, marime, culoare, pret_lista 
    FROM variante_produs;
  v_c c%ROWTYPE;
BEGIN
  OPEN c;
  FOR v_c IN c
  LOOP
    DBMS_OUTPUT.PUT_LINE('Product variant ' || v_c.id_varianta || ' has size ' || v_c.marime || ' and color ' || v_c.culoare || ' at the price of ' || v_c.pret_lista);
  END LOOP;
  CLOSE c; -- Best practice to close the cursor after loop completion
  
EXCEPTION
  WHEN CURSOR_ALREADY_OPEN THEN
    DBMS_OUTPUT.PUT_LINE('An attempt was made to open a cursor that was already previously opened - Error.');
END;
/

-- 4. Delete a category safely, handling dependencies where child records exist.
DECLARE
  e_categoria_are_copii EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_categoria_are_copii, -2292);
  v_id_cat produse.id_categorie%TYPE := &id_cat;
BEGIN
  DELETE FROM categorii 
  WHERE id_categorie = v_id_cat;
  
  IF SQL%FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Category was successfully deleted.');
  ELSE 
    DBMS_OUTPUT.PUT_LINE('Category ' || v_id_cat || ' does not exist.');
  END IF;
  
EXCEPTION 
  WHEN e_categoria_are_copii THEN
    DBMS_OUTPUT.PUT_LINE('Cannot delete this category! There are products in the store belonging to it.');
    DBMS_OUTPUT.PUT_LINE('Error message: ' || SQLERRM);
END;
/



-- B. Explicit Exceptions

-- 1. Automatic customer categorization. If order count = 3 -> VIP, < 3 -> MODERATE, > 3 -> raise a custom exception.
DECLARE
  v_id_client clienti.id_client%TYPE := &id_client;
  v_nr_comenzi NUMBER;
  e_nu_are_comenzi EXCEPTION;
  v_status VARCHAR2(20);
BEGIN
  SELECT COUNT(*) 
  INTO v_nr_comenzi 
  FROM comenzi 
  WHERE id_client = v_id_client;
  
  IF v_nr_comenzi = 0 THEN
    RAISE e_nu_are_comenzi;
  ELSE
    CASE 
      WHEN v_nr_comenzi = 3 THEN v_status := 'VIP';
      WHEN v_nr_comenzi < 3 THEN v_status := 'MODERATE';
    END CASE;
    
    DBMS_OUTPUT.PUT_LINE('Client ' || v_id_client || ' has placed ' || v_nr_comenzi || ' orders, and thus has the status: ' || v_status);
  END IF;
EXCEPTION
  WHEN e_nu_are_comenzi THEN
    DBMS_OUTPUT.PUT_LINE('Client ' || v_id_client || ' does not exist or has no orders; therefore, they are inactive.');
  WHEN CASE_NOT_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Client ' || v_id_client || ' is very loyal, having placed more than 3 orders.');
END;
/


-- 2. Return all variants of a product by entering its ID from the keyboard. Handle all exceptions.
DECLARE
  v_id_produs produse.id_produs%TYPE := &id_produs;
  CURSOR c(p_id NUMBER) IS 
    SELECT * 
    FROM variante_produs 
    WHERE id_produs = p_id;
  v_exista NUMBER;
  v_number NUMBER;
  e_nu_exista_variante EXCEPTION;
BEGIN
  SELECT COUNT(*) 
  INTO v_exista 
  FROM produse 
  WHERE id_produs = v_id_produs;
  
  IF v_exista = 0 THEN
    RAISE_APPLICATION_ERROR(-20001, 'The product does not exist in the store database.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Variants for product ' || v_id_produs || ' are:');
    v_number := 0;
    FOR v_c IN c(v_id_produs)
    LOOP
      v_number := v_number + 1;
      DBMS_OUTPUT.PUT_LINE('Variant ' || v_c.id_varianta || ' - size: ' || v_c.marime || ' - color: ' || v_c.culoare || ' - code: ' || v_c.cod_produs_ales || ' - price: ' || v_c.pret_lista);
    END LOOP;
  END IF;
  
  IF v_number = 0 THEN
    RAISE e_nu_exista_variante;
  END IF;
EXCEPTION
  WHEN e_nu_exista_variante THEN
    DBMS_OUTPUT.PUT_LINE('The given product has no variants in the store.');
END;
/


-- 3. Simulate placing an order on the site. Request a quantity for a specific product; throw an exception if it exceeds stock, otherwise reduce stock.
DECLARE
  v_id_varianta stocuri.id_varianta%TYPE := &id_varianta;
  v_cantitate_dorita NUMBER := &cantitate_dorita;
  v_cantitate_disp stocuri.cantitate_disponibila%TYPE;
  v_exista NUMBER := 0;
  e_nu_exista EXCEPTION;
  e_cantitate_prea_mare EXCEPTION;
BEGIN
  SELECT COUNT(*) 
  INTO v_exista 
  FROM stocuri 
  WHERE id_varianta = v_id_varianta;
  
  IF v_exista = 0 THEN 
    RAISE e_nu_exista;
  ELSE
    SELECT cantitate_disponibila 
    INTO v_cantitate_disp 
    FROM stocuri 
    WHERE id_varianta = v_id_varianta;
    
    IF v_cantitate_dorita > v_cantitate_disp THEN
      RAISE e_cantitate_prea_mare;
    ELSE 
      UPDATE stocuri
      SET cantitate_disponibila = cantitate_disponibila - v_cantitate_dorita
      WHERE id_varianta = v_id_varianta;
      
      COMMIT;
      DBMS_OUTPUT.PUT_LINE('Stock reservation was successfully registered; proceeding to actual order placement and payment.');
    END IF;
  END IF;
  
EXCEPTION
  WHEN e_nu_exista THEN
    DBMS_OUTPUT.PUT_LINE('Product variant ' || v_id_varianta || ' does not exist in our store stock.');
  WHEN e_cantitate_prea_mare THEN
    DBMS_OUTPUT.PUT_LINE('Cannot order a quantity greater than what is available in stock.');
END;
/
