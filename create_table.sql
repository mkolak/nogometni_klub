---------------------------------------------

-- DROP TABLE IGRAC_NASTUP;
-- DROP TABLE UTAKMICA;
-- DROP TABLE IGRAC_REGISTRACIJA;
-- DROP TABLE UGOVOR_IGRAC;
-- DROP TABLE UGOVOR_OSOBLJE;
-- DROP TABLE UGOVOR;
-- DROP TABLE ULOGA;
-- DROP TABLE SEZONA;
-- DROP TABLE OSOBA;

---------------------------------------------

-- 1. OSOBA
CREATE TABLE OSOBA (
    osoba_id INTEGER CONSTRAINT osoba_pk PRIMARY KEY,
    ime VARCHAR2(15) NOT NULL,
    prezime VARCHAR2(15) NOT NULL,
    datum_rodenja DATE NOT NULL,
    OIB VARCHAR2(11) UNIQUE NOT NULL,
    drzavljanstvo VARCHAR2(15) NOT NULL
);

-- 2. SEZONA
CREATE TABLE SEZONA (
    godina_pocetka INTEGER CONSTRAINT sezona_pk PRIMARY KEY
);

-- 3. ULOGA
CREATE TABLE ULOGA (
    uloga_id INTEGER CONSTRAINT uloga_pk PRIMARY KEY,
    naziv VARCHAR2(30) NOT NULL,
    opis VARCHAR2(90)
);

-- 4. UGOVOR
CREATE TABLE UGOVOR (
    ugovor_id INTEGER CONSTRAINT ugovor_pk PRIMARY KEY,
    datum_pocetka DATE NOT NULL,
    datum_isteka DATE,
    datum_raskida DATE,
    mjesecna_placa INTEGER NOT NULL,
    osoba_id INTEGER CONSTRAINT ugovor_osoba_fk REFERENCES osoba(osoba_id) NOT NULL,
    CONSTRAINT raskid_istek CHECK ((datum_raskida <= datum_isteka) AND (datum_pocetka <= datum_isteka) AND (datum_pocetka <= datum_raskida))
);

-- 5. UGOVOR_OSOBLJE
CREATE TABLE UGOVOR_OSOBLJE(
    ugovor_id INTEGER CONSTRAINT ugovor_osoblje_pk PRIMARY KEY,
    uloga_id INTEGER CONSTRAINT ugovor_osoblje_uloga_fk REFERENCES uloga(uloga_id) NOT NULL,
    CONSTRAINT ugovor_osoblje_fk FOREIGN KEY (ugovor_id) REFERENCES ugovor(ugovor_id) 
);

-- 6. UGOVOR_IGRAC
CREATE TABLE UGOVOR_IGRAC(
    ugovor_id INTEGER CONSTRAINT ugovor_igrac_pk PRIMARY KEY,
    odstetna_klauzula INTEGER,
    bonus_za_izvedbu INTEGER,
    CONSTRAINT ugovor_igrac_fk FOREIGN KEY (ugovor_id) REFERENCES ugovor(ugovor_id)
);

-- 7. IGRAC_REGISTRACIJA
CREATE TABLE IGRAC_REGISTRACIJA(
    broj_registracije INTEGER CONSTRAINT igrac_registracija_pk PRIMARY KEY,
    sezona INTEGER CONSTRAINT igrac_registracija_sezona_fk REFERENCES sezona(godina_pocetka) NOT NULL,
    ugovor_id INTEGER CONSTRAINT igrac_registracija_ugovor_fk REFERENCES ugovor_igrac(ugovor_id) NOT NULL
);

-- OKIDAČ KOJI PROVJERAVA DA LI IGRAČ IMA VALJANI UGOVOR ZA TU SEZONU
CREATE OR REPLACE TRIGGER valid_contract_season_registration 
BEFORE INSERT OR UPDATE ON IGRAC_REGISTRACIJA
FOR EACH ROW
DECLARE
    ugovor_pocetak UGOVOR.datum_pocetka%type;
    ugovor_raskid UGOVOR.datum_raskida%type;
BEGIN
    SELECT datum_pocetka, datum_raskida INTO ugovor_pocetak, ugovor_raskid
    FROM UGOVOR WHERE ugovor_id = :new.ugovor_id;

    IF(TO_DATE('01-Jul-' || :new.sezona) >= ugovor_raskid OR TO_DATE('01-Jul-' || (:new.sezona + 1)) <= ugovor_pocetak) THEN
        RAISE_APPLICATION_ERROR(-20222, 'Igrač nema važeći ugovor za tu sezonu');
    END IF;
END;
/

-- 8.UTAKMICA
CREATE TABLE UTAKMICA(
    utakmica_id INTEGER CONSTRAINT utakmica_pk PRIMARY KEY,
    datum_odigravanja DATE NOT NULL,
    natjecanje VARCHAR(40) NOT NULL,
    domaca_utakmica NUMBER(1) NOT NULL,
    protivnik VARCHAR(25) NOT NULL,
    zabijeni_golovi INTEGER NOT NULL,
    primljeni_golovi INTEGER NOT NULL,
    opis VARCHAR(25)
);

-- 9.IGRAC_NASTUP
CREATE TABLE IGRAC_NASTUP(
    broj_registracije INTEGER CONSTRAINT igrac_nastup_registracija_fk REFERENCES igrac_registracija(broj_registracije) NOT NULL,
    utakmica_id INTEGER CONSTRAINT igrac_nastup_utakmica_fk REFERENCES utakmica(utakmica_id) NOT NULL,
    pozicija VARCHAR2(20) NOT NULL,
    zuti_karton NUMBER(1) DEFAULT 0 NOT NULL,
    crveni_karton NUMBER(1) DEFAULT 0 NOT NULL,
    postignuti_golovi INTEGER DEFAULT 0 NOT NULL,
    usao_u_igru NUMBER(1) DEFAULT 0 NOT NULL,
    pocetni_sastav NUMBER(1) DEFAULT 0 NOT NULL,
    CONSTRAINT pocetak_ili_zamjena
    CHECK ((usao_u_igru = 0 AND pocetni_sastav = 1) OR (usao_u_igru = 1 AND pocetni_sastav = 0) OR (usao_u_igru = 0 AND pocetni_sastav = 0)),
    CONSTRAINT moguca_pozicija
    CHECK (pozicija IN ('Golman', 'Branič', 'Veznjak', 'Napadač')),
    CONSTRAINT igrac_nastup_pk PRIMARY KEY(broj_registracije, utakmica_id)
);


-- OKIDAČ KOJI OSIGURAVA DA SE NE MOŽE UNIJETI VIŠE OD 11 IGRAČA U POČETNI SASTAV

CREATE OR REPLACE TRIGGER eleven_players_in_field 
BEFORE INSERT OR UPDATE ON IGRAC_NASTUP
FOR EACH ROW
WHEN (new.pocetni_sastav != 0)
DECLARE
    broj_igraca INTEGER;
BEGIN
    SELECT COUNT(*) INTO broj_igraca
    FROM IGRAC_NASTUP
    WHERE utakmica_id = :new.utakmica_id AND pocetni_sastav != 0;

    IF (broj_igraca = 11) THEN
        RAISE_APPLICATION_ERROR(-20224, 'Utakmicu ne može započeti više od 11 igrača.');
    END IF;
END;
/

-- OKIDAČ KOJI OSIGURAVA DA BROJ POSTIGNUTIH GOLOVA KLUBA BUDE >= OD SUME POSTIGNUTIH GOLOVA IGRAČA(>= ZBOG POTENCIJALNIH AUTOGOLOVA)

CREATE OR REPLACE TRIGGER matching_goal_count
BEFORE INSERT OR UPDATE ON IGRAC_NASTUP
FOR EACH ROW
DECLARE
    broj_golova_nastup INTEGER;
    broj_golova_utakmica INTEGER;
BEGIN
    SELECT SUM(postignuti_golovi) + :new.postignuti_golovi INTO broj_golova_nastup
    FROM IGRAC_NASTUP
    WHERE utakmica_id = :new.utakmica_id;

    SELECT zabijeni_golovi INTO broj_golova_utakmica
    FROM UTAKMICA
    WHERE utakmica_id = :new.utakmica_id; 
    IF (broj_golova_nastup > broj_golova_utakmica) THEN
        RAISE_APPLICATION_ERROR(-20223, 'Različit broj postignutih golova u tablicama utakmica i igrač nastup');
    END IF;
END;
/

-- OKIDAČ KOJI OSIGURAVA DA SVI IGRAČI KOJI NASTUPAJU UTAKMICI IMAJU REGISTRACIJU ZA ISTU SEZONU TE DA SEZONA ODGOVARA DATUMU UTAKMICE

CREATE OR REPLACE TRIGGER matching_season_and_matchdate
BEFORE INSERT OR UPDATE ON IGRAC_NASTUP
FOR EACH ROW
DECLARE
    are_registrations_equal INTEGER;
    new_insert_season INTEGER;
    reg_season INTEGER;
    matchdate DATE;
BEGIN
    SELECT COUNT(*) INTO are_registrations_equal
    FROM (
        SELECT SEZONA
        FROM IGRAC_NASTUP
        INNER JOIN IGRAC_REGISTRACIJA
        USING(broj_registracije)
        WHERE :new.utakmica_id = utakmica_id
        GROUP BY SEZONA
        );
        
        SELECT SEZONA INTO new_insert_season
        FROM IGRAC_REGISTRACIJA
        WHERE :new.broj_registracije = broj_registracije;  

    IF (are_registrations_equal = 1) THEN
        SELECT DISTINCT SEZONA INTO reg_season 
        FROM IGRAC_NASTUP
        INNER JOIN IGRAC_REGISTRACIJA
        USING(broj_registracije)
        WHERE :new.utakmica_id = utakmica_id;
        SELECT datum_odigravanja INTO matchdate
        FROM UTAKMICA
        WHERE :new.utakmica_id = utakmica_id;
        IF (new_insert_season != reg_season) THEN
            RAISE_APPLICATION_ERROR(-20228, 'Unesena registracija nema valjanu sezonu');
        END IF;
        IF (TO_DATE('01-Jun-' || reg_season) >= matchdate OR matchdate >= TO_DATE('01-Jun-' || (reg_season + 1))) THEN
            RAISE_APPLICATION_ERROR(-20226, 'Registracije ne odgovaraju sezoni u kojoj se utakmica odigrava');
        END IF;
    ELSIF(are_registrations_equal > 1) THEN
        RAISE_APPLICATION_ERROR(-20227, 'U zapisniku se nalaze registracije za različite sezone');
    END IF;
END;
/

---------------------------------------------------------------
-- PROCEDURE I FUNKCIJE ---------------------------------------
---------------------------------------------------------------

-- PROCEDURA ZA UPDATE VRIJEDNOSTI DATUMA RASKIDA U ONOM TRENUTKU KAD JE PROŠAO DATUM ISTEKA UGOVORA. 
CREATE OR REPLACE PROCEDURE update_datum_raskid AS
BEGIN
    UPDATE UGOVOR uout
    SET datum_raskida = datum_isteka
    WHERE datum_isteka <= CURRENT_DATE;
END;
/
-- PROCEDURA KOJA ZA DANU UTAKMICU ISPISUJE IMENA I PREZIMENA IGRAČA KOJI SU ZAIGRALI U POČETNOJ POSTAVI
-- SET SERVEROUTPUT ON;

CREATE OR REPLACE PROCEDURE starting_lineup(
    p_utakmica_id IN UTAKMICA.UTAKMICA_ID%type
) AS
utakmica_exists INTEGER;
v_ime OSOBA.ime%TYPE;
v_prezime OSOBA.ime%TYPE;
CURSOR v_osoba_kursor IS
    SELECT ime, prezime
    FROM IGRAC_NASTUP
    INNER JOIN IGRAC_REGISTRACIJA
    USING (broj_registracije)
    INNER JOIN UGOVOR
    USING (ugovor_id)
    INNER JOIN OSOBA
    USING (osoba_id)
    WHERE utakmica_id = p_utakmica_id AND POCETNI_SASTAV != 0;
BEGIN
    SELECT COUNT(*) INTO utakmica_exists
    FROM UTAKMICA
    WHERE p_utakmica_id = utakmica_id;    

    IF (utakmica_exists > 0) THEN
        OPEN v_osoba_kursor;

        LOOP
            FETCH v_osoba_kursor
            INTO v_ime, v_prezime;
            DBMS_OUTPUT.PUT_LINE(v_ime || ' ' || v_prezime);
        EXIT WHEN v_osoba_kursor%NOTFOUND;
        END LOOP;
        CLOSE v_osoba_kursor;
    ELSE
    DBMS_OUTPUT.PUT_LINE('Utakmica ne postoji');
    END IF;
END;
/

-- CALL starting_lineup(8);

---------------------------------------------------------------
-- INDEKSI ----------------------------------------------------
---------------------------------------------------------------

CREATE INDEX i_osoba_ime_prezime ON OSOBA(ime, prezime);

CREATE INDEX i_utakmica_protivnik ON UTAKMICA(protivnik);

CREATE BITMAP INDEX i_igrac_nastup_pozicija ON IGRAC_NASTUP(pozicija);

-- SELECT ul.naziv, COUNT(*)
-- FROM osoba o
-- INNER JOIN ugovor u
-- USING (osoba_id)
-- INNER JOIN ugovor_osoblje uo
-- USING (ugovor_id)
-- INNER JOIN uloga ul
-- USING (uloga_id)
-- GROUP BY ul.naziv;