-- JEDNOSTAVNI UPITI

-- 1. Tražimo sve ugovore koji trenutno traju
SELECT *
FROM UGOVOR
WHERE DATUM_RASKIDA IS NULL;

-- 2. Tražimo sve osobe u klubu koje su rođene poslije 1983. godine
SELECT *
FROM OSOBA
WHERE (EXTRACT(YEAR FROM DATUM_RODENJA) >= 1983);

-- 3. Tražimo sve domaće utakmice na kojima je ukupno postignuto barem 4 gola
SELECT *
FROM UTAKMICA
WHERE ZABIJENI_GOLOVI + PRIMLJENI_GOLOVI >= 3 AND DOMACA_UTAKMICA = 1;

-- 4. Tražimo koliko je golova postignuto sa koje pozicije. (Koliko su golova zabili veznjaci, koliko napadači, a koliko braniči)
SELECT POZICIJA, SUM(POSTIGNUTI_GOLOVI)
FROM IGRAC_NASTUP
WHERE POSTIGNUTI_GOLOVI >= 1
GROUP BY POZICIJA;

-- 5. Tražimo koliko je golova primljeno u sezoni 2019./2020.
SELECT SUM(PRIMLJENI_GOLOVI)
FROM UTAKMICA
WHERE DATUM_ODIGRAVANJA >= TO_DATE('01-Jun-2019', 'dd-Mon-yyyy') AND DATUM_ODIGRAVANJA <= TO_DATE('01-Jun-2020', 'dd-Mon-yyyy'); 

-- SLOŽENI UPITI

-- 1. Tražimo ime i prezime, te datum pocetka i isteka ugovora za sve igrače koji imaju trenutno važeći ugovor
SELECT ime, prezime, datum_pocetka, datum_isteka
FROM OSOBA
INNER JOIN UGOVOR
USING (osoba_id)
INNER JOIN UGOVOR_IGRAC
USING (ugovor_id)
WHERE DATUM_POCETKA <= SYSDATE AND DATUM_ISTEKA >= SYSDATE;

-- 2. Tražimo imena i prezimena svih igrača koji su postigli barem jedan gol na nekoj od utakmica
SELECT DISTINCT ime || ' ' || prezime "Ime i prezime"
FROM IGRAC_NASTUP
INNER JOIN IGRAC_REGISTRACIJA
USING (broj_registracije)
INNER JOIN UGOVOR
USING (ugovor_id)
INNER JOIN OSOBA
USING (osoba_id)
WHERE (POSTIGNUTI_GOLOVI >= 1);

-- 3. Tražimo početni sastav (Ime, prezime, pozicija) na utakmici 1.kola sezone 2019/20.
SELECT ime, prezime, pozicija
FROM OSOBA
INNER JOIN UGOVOR
USING (osoba_id)
INNER JOIN IGRAC_REGISTRACIJA
USING (ugovor_id)
INNER JOIN IGRAC_NASTUP
USING (broj_registracije)
INNER JOIN SEZONA
ON (IGRAC_REGISTRACIJA.sezona = sezona.GODINA_POCETKA)
INNER JOIN UTAKMICA
USING (utakmica_id)
WHERE UTAKMICA.OPIS = '1.kolo' AND GODINA_POCETKA = 2019 AND POCETNI_SASTAV = 1;

-- 4. Koji je golman primio najviše golova na jednoj utakmici
SELECT ime, prezime, pozicija
FROM OSOBA
INNER JOIN UGOVOR
USING (osoba_id)
INNER JOIN IGRAC_REGISTRACIJA
USING (ugovor_id)
INNER JOIN IGRAC_NASTUP
USING (broj_registracije)
INNER JOIN SEZONA
ON (IGRAC_REGISTRACIJA.sezona = sezona.GODINA_POCETKA)
INNER JOIN UTAKMICA
USING (utakmica_id)
WHERE utakmica_id = (
        SELECT UTAKMICA_ID
        FROM UTAKMICA
        WHERE PRIMLJENI_GOLOVI = (SELECT MAX(PRIMLJENI_GOLOVI)
                                  FROM UTAKMICA))
      AND pozicija = 'Golman' AND POCETNI_SASTAV = 1;

-- 5. Tražimo sve imena i prezimena svih igrača koji imaju odštetnu klauzulu
SELECT ime, prezime, ODSTETNA_KLAUZULA
FROM OSOBA
INNER JOIN UGOVOR
USING (osoba_id)
INNER JOIN UGOVOR_IGRAC
USING (ugovor_id)
WHERE ODSTETNA_KLAUZULA IS NOT NULL;

-- UPITI S AGREGIRAJUĆIM FUNKCIJAMA

-- 1. Koliko je ukupno novaca klub potrošio na plaće u ožujku 2019. (Igrači i osoblje).
SELECT SUM(MJESECNA_PLACA)
FROM UGOVOR
WHERE (DATUM_POCETKA <= TO_DATE('01-Mar-2019', 'dd-Mon-yyyy') AND (datum_raskida >= TO_DATE('01-Apr-2019', 'dd-Mon-yyyy')) or datum_raskida IS NULL);

-- 2. Koliko je bonusa svaki od igrača zaradio tijekom igranja za klub (bonus_za_izvedbu se dobije za svaki postignuti gol) 
--    SAMO ONI IGRAČI KOJI IMAJU BONUS(NOT NULL) i KOJI SU ZABILI BAR JEDAN GOL
SELECT osoba_id, ime, prezime, SUM(POSTIGNUTI_GOLOVI)*BONUS_ZA_IZVEDBU "Bonus"
FROM IGRAC_NASTUP
INNER JOIN IGRAC_REGISTRACIJA ir
USING (broj_registracije)
INNER JOIN UGOVOR u
ON (u.ugovor_id = ir.ugovor_id)
INNER JOIN OSOBA
USING (osoba_id)
INNER JOIN UGOVOR_IGRAC ui
ON (u.ugovor_id = ui.ugovor_id)
WHERE POSTIGNUTI_GOLOVI >= 1 AND BONUS_ZA_IZVEDBU IS NOT NULL
GROUP BY osoba_id, ime, prezime, bonus_za_izvedbu;

-- 3. Tražimo prosječnu plaću s obzirom na ulogu (igrači i osoblje)
SELECT naziv, AVG(MJESECNA_PLACA) "Prosječna plaća"
FROM UGOVOR
INNER JOIN UGOVOR_OSOBLJE
USING (ugovor_id)
INNER JOIN ULOGA
USING (uloga_id)
GROUP BY naziv
UNION
SELECT 'Igrač' "naziv", ROUND(AVG(MJESECNA_PLACA),2)
FROM UGOVOR
INNER JOIN UGOVOR_IGRAC
USING (ugovor_id)
ORDER BY "Prosječna plaća" DESC;

-- 4. Tražimo koliko je koji igrač puta zaigrao za klub. Računaju se ulasci s klupe i početni sastav. Zapis u IGRAC_NASTUP ne mora nužno značiti da je igrač zaigrao na utakmici
SELECT ime || ' ' || prezime "Ime i prezime", COUNT(*) "Broj nastupa"
FROM IGRAC_NASTUP
INNER JOIN IGRAC_REGISTRACIJA ir
USING (broj_registracije)
INNER JOIN UGOVOR u
ON (u.ugovor_id = ir.ugovor_id)
INNER JOIN OSOBA
USING (osoba_id)
WHERE USAO_U_IGRU = 1 OR POCETNI_SASTAV = 1
GROUP BY ime || ' ' || prezime
ORDER BY "Broj nastupa" DESC;

-- 5. Tražimo koliko je žutih, a koliko crvenih kartona bilo na utakmicama
SELECT DATUM_ODIGRAVANJA, PROTIVNIK, SUM(ZUTI_KARTON) "Zuti kartoni", SUM(CRVENI_KARTON) "Crveni kartoni"
FROM IGRAC_NASTUP
INNER JOIN UTAKMICA
USING (utakmica_id)
GROUP BY DATUM_ODIGRAVANJA, PROTIVNIK;
