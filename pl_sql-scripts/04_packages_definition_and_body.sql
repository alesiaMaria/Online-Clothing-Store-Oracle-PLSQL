=====================================================================
  PACKAGES
=====================================================================

-- A. Package 1 : Operational mangement

CREATE OR REPLACE PACKAGE gestiune_operationala
is
procedure actualizeaza_pret_brand(p_brand produse.brand%TYPE, p_procent number);
procedure actualizare_prag( p_prag_minim number, p_valoare number, p_nr_variante OUT number);
function calcul_stoc_total(p_id_produs  produse.id_produs%TYPE)
return number;
function verificare_stoc(p_id  IN stocuri.id_varianta%TYPE)
return varchar2;
end gestiune_operationala;
/

CREATE OR REPLACE PACKAGE BODY gestiune_operationala
is
 procedure actualizeaza_pret_brand(p_brand produse.brand%TYPE, p_procent number)
IS
v_nr_actualizari number;
e_nu_exista exception;
begin
update variante_produs
set pret_lista=pret_lista+pret_lista*p_procent
where id_produs in ( select id_produs from produse where brand=p_brand);
v_nr_actualizari:=SQL%ROWCOUNT;
if v_nr_actualizari=0 then
raise e_nu_exista;
else dbms_output.put_line(' S-au actualizat ' || v_nr_actualizari || ' variante de produs');
end if;
exception
when e_nu_exista then
dbms_output.put_line(' Brand-ul ' || p_brand || ' nu exista in magazinul nostru, sau nu are variante de produs.');
end actualizeaza_pret_brand;
 
procedure actualizare_prag( p_prag_minim number, p_valoare number, p_nr_variante OUT number)
IS
begin
update stocuri
set cantitate_disponibila=cantitate_disponibila+p_valoare
where cantitate_disponibila < p_prag_minim;
p_nr_variante :=SQL%ROWCOUNT;
commit;
end actualizare_prag;
 
function calcul_stoc_total(p_id_produs  produse.id_produs%TYPE)
return number
is
v_exista number;
e_nu_exista exception;
v_total number;
begin
select count(*) into v_exista from produse where id_produs=p_id_produs;
if v_exista=0 then
raise e_nu_exista;
else
select sum(s.cantitate_disponibila) into v_total
from stocuri s
left join variante_produs vp on s.id_varianta=vp.id_varianta
where vp.id_produs=p_id_produs;
return v_total;
end if;
exception
when e_nu_exista then
dbms_output.put_line(' Produsul nu exista in magazin ');
return 0;
end calcul_stoc_total;
 
function verificare_stoc(p_id  IN stocuri.id_varianta%TYPE)
return varchar2
is
v_prag stocuri.prag_minim%TYPE;
v_cantitate stocuri.cantitate_disponibila%TYPE;
v_test number;
begin
select count(*) into v_test from stocuri where id_varianta=p_id;
if v_test=0 then 
return 0;
end if;
select prag_minim,cantitate_disponibila into v_prag,v_cantitate from stocuri where id_varianta=p_id;
CASE
WHEN v_prag<v_cantitate THEN RETURN 'STOC BUN';
WHEN v_prag = v_cantitate THEN RETURN 'STOC LIMITA';
ELSE RETURN 'STOC INSUFICIENT';
end case;
end verificare_stoc;
end gestiune_operationala;
/


-- Testing the package: 
   -Procedures: 
a.	execute gestiune_operationala.actualizeaza_pret_brand('BasicWear',0.15);
b. declare 
v_nr_actualizari number; 
begin 
gestiune_operationala.actualizare_prag(120,30,v_nr_actualizari); 
if v_nr_actualizari=0 then 
 dbms_output.put_line(' S-au realizat 0 actualizari. Toate produsele au stocul peste pragul minim dat'); 
 else 
 dbms_output.put_line(' S au realizat ' || v_nr_actualizari || ' actualizari asupra stocurilor'); 
end if; 
 end; 
/
     -Functions:
a. declare 
v_id_varianta stocuri.id_varianta%TYPE:=&id_varianta;
v_status varchar2(90);
begin
v_status:=gestiune_operationala.verificare_stoc(v_id_varianta);
dbms_output.put_line(' Stocul variantei de produs ' || v_id_varianta || ' are nivel : ' || v_status);
end;
/
b.	declare
v_id_produs variante_produs.id_produs%TYPE:=&id_produs;
v_total number;
begin
v_total:= calcul_stoc_total(v_id_produs);
dbms_output.put_line(' Cantitatea diponibila totala din produsul ' || v_id_produs ||  ' este de ' || v_total);
end;
/



-- A. Package 2 : Sales and clients mangement

CREATE OR REPLACE PACKAGE gestiune_vanzari_si_clienti
is
procedure realizare_plata_comanda( p_id_comanda plati.id_comanda%TYPE, p_metoda  plati.metoda%TYPE, p_suma  plati.suma%TYPE);
procedure adauga_voucher(p_id_varianta  variante_produs.id_varianta%TYPE, p_pret_final IN OUT variante_produs.pret_lista%TYPE);
function calcul_valoare_comenzi( p_email  clienti.email%TYPE)
return number;
function luni_inactivitate_clienti(p_id_client  clienti.id_client%TYPE)
return number;
end gestiune_vanzari_si_clienti;
/
CREATE OR REPLACE PACKAGE BODY gestiune_vanzari_si_clienti
is
procedure realizare_plata_comanda( p_id_comanda plati.id_comanda%TYPE, p_metoda  plati.metoda%TYPE, p_suma  plati.suma%TYPE)
IS
v_total_comanda comenzi.total_comanda%TYPE;
e_suma_prea_mica exception;
begin
select total_comanda into v_total_comanda from comenzi where id_comanda=p_id_comanda;
if p_suma<v_total_comanda then
raise e_suma_prea_mica;
else
insert into plati(id_comanda,data_plata,metoda,suma,status_plata) values (p_id_comanda,sysdate,p_metoda,p_suma,'CONFIRMATA');
update comenzi
set status_comanda='PLATITA'
where id_comanda=p_id_comanda;
dbms_output.put_line( ' Plata comenzii ' || p_id_comanda || ' a fost inregistrata cu succes , cu suma totala de ' || p_suma || ' lei');
end if;
exception
when no_data_found then
dbms_output.put_line(' Comanda ' || p_id_comanda || ' nu exista ');
when e_suma_prea_mica then
dbms_output.put_line(' Fonduri insuficiente. Suma este prea mica pentru achitarea integrala a comenzii ' || p_id_comanda);
end realizare_plata_comanda;
 
procedure adauga_voucher(p_id_varianta  variante_produs.id_varianta%TYPE, p_pret_final IN OUT variante_produs.pret_lista%TYPE)
IS 
v_discount number;
e_nu_este_valid exception;
begin
if p_pret_final <=0 then
raise e_nu_este_valid;
end if;
v_discount:=CASE WHEN p_pret_final>500 then 0.20
WHEN p_pret_final between 100 and 500 then 0.15
else 0
end;
p_pret_final:=p_pret_final + p_pret_final*v_discount;
dbms_output.put_line(' Discountul de ' || v_discount*100 || ' a fost aplicat cu succes');
exception 
when e_nu_este_valid then
dbms_output.put_line(' Pretul trebuie sa fie un numar pozitiv si diferit de zero ');
end adauga_voucher;
 
function calcul_valoare_comenzi( p_email  clienti.email%TYPE)
RETURN number
is 
v_exista number;
e_nu_exista exception;
v_total number;
begin
select count(*) into v_exista from clienti where email=p_email;
if v_exista=0 then
raise e_nu_exista;
else
select sum(total_comanda) into v_total from comenzi join clienti using(id_client) where email=p_email;
if v_total is null then
return 0;
else return v_total;
end if;
end if;
exception
when e_nu_exista then
return 0;
end calcul_valoare_comenzi;
 
function luni_inactivitate_clienti(p_id_client  clienti.id_client%TYPE)
return number
is
v_exista number;
v_ultima_data date;
v_luni_inactive number;
begin
select count(*) into v_exista from clienti where id_client=p_id_client;
if v_exista=0 then
return 0;
end if;
 
select max(data_comanda) into v_ultima_data from comenzi where id_client=p_id_client;
if v_ultima_data is null then 
return 0;
end if;
 
v_luni_inactive:= sysdate-v_ultima_data;
return round(v_luni_inactive);
end luni_inactivitate_clienti;
 
end gestiune_vanzari_si_clienti;
/

-- Testing the package: 
   -Procedures: 
a.  begin 
gestiune_vanzari_si_clienti.realizare_plata_comanda(1, 'CARD', 200.00); 
end; 
/

b. declare 
v_id_varianta variante_produs.id_varianta%TYPE:=&id_varianta; 
v_pret variante_produs.pret_lista%TYPE; 
begin 
select pret_lista into v_pret from variante_produs where id_varianta=v_id_varianta; 
dbms_output.put_line(' Pretul initial este : ' || v_pret); 
adauga_voucher(v_id_varianta,v_pret); 
dbms_output.put_line(' Pretul dupa aplicarea discountului este : ' || v_pret); 
exception 
when no_data_found then 
dbms_output.put_line(' Varianta de produs ' || v_id_varianta || ' nu exista'); 
end; 
/

     -Functions:
a. declare 
v_email clienti.email%TYPE:='&email'; 
v_total number; 
begin 
v_total:=calcul_valoare_comenzi(v_email); 
dbms_output.put_line(' Valoarea totala a tuturor comenzilor intreprinse folosind email-ul ' || v_email|| ' este de ' || v_total); 
end; 
/

b. declare 
v_id clienti.id_client%TYPE:=&id_client; 
v_luni number; 
begin 
v_luni:=luni_inactivitate_clienti(v_id); 
dbms_output.put_line(' Clientul ' || v_id || ' are o perioada de inactivitate de ' || v_luni || ' luni.'); 
end; 
/
