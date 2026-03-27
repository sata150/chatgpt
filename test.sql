CREATE TABLE amr.amr_code
(
   code_id        numeric(22)    NOT NULL,
   code_group_fk  numeric(22),
   code           varchar(255),
   valid_from     date,
   valid_to       date
);

ALTER TABLE amr.amr_code
  ADD CONSTRAINT pk_code PRIMARY KEY (code_id);

CREATE INDEX amr.code_indx_1
   ON amr.amr_code (code ASC);

CREATE INDEX amr.code_indx_3
   ON amr.amr_code (code_group_fk ASC, code ASC);

CREATE INDEX amr.code_indx_2
   ON amr.amr_code (code_group_fk ASC);

COMMENT ON TABLE amr.amr_code IS 'Kódtábla';
COMMENT ON COLUMN amr.amr_code.code_id IS 'Egyedi azonosító';
COMMENT ON COLUMN amr.amr_code.code_group_fk IS 'Kód csoport azonosító';
COMMENT ON COLUMN amr.amr_code.code IS 'Kód';
COMMENT ON COLUMN amr.amr_code.valid_from IS 'Érvényesség kezdete';
COMMENT ON COLUMN amr.amr_code.valid_to IS 'Érvényesség vége';

GRANT DELETE, SELECT, UPDATE, INSERT ON amr.amr_code TO methodus_proxy;
GRANT UPDATE, DELETE, SELECT, INSERT ON amr.amr_code TO amr_proxy;
GRANT REFERENCES, SELECT, TRIGGER, DELETE, TRUNCATE, INSERT, UPDATE ON amr.amr_code TO amr;
GRANT SELECT ON amr.amr_code TO methodus;
GRANT SELECT ON amr.amr_code TO amr_db_readonly;


ALTER TABLE amr_code
  ADD CONSTRAINT fk_amr_code_group FOREIGN KEY (code_group_fk)
  REFERENCES amr.amr_code_group (code_group_id) 
  ON UPDATE NO ACTION
  ON DELETE NO ACTION;

CREATE TABLE amr.amr_code_group
(
   code_group_id   numeric(22)    NOT NULL,
   designation     varchar(255),
   is_editable_fl  bool
);

ALTER TABLE amr.amr_code_group
  ADD CONSTRAINT pk_code_group PRIMARY KEY (code_group_id);

COMMENT ON TABLE amr.amr_code_group IS 'Kód csoport tábla';
COMMENT ON COLUMN amr.amr_code_group.code_group_id IS 'Egyedi azonosító';
COMMENT ON COLUMN amr.amr_code_group.designation IS 'Leírás';
COMMENT ON COLUMN amr.amr_code_group.is_editable_fl IS 'Szerkeszthetõ? (1: igen, 0: nem)';

GRANT DELETE, UPDATE, SELECT, INSERT ON amr.amr_code_group TO methodus_proxy;
GRANT UPDATE, DELETE, SELECT, INSERT ON amr.amr_code_group TO amr_proxy;
GRANT REFERENCES, SELECT, TRIGGER, DELETE, TRUNCATE, INSERT, UPDATE ON amr.amr_code_group TO amr;
GRANT SELECT ON amr.amr_code_group TO amr_db_readonly;

CREATE TABLE amr.amr_code_languages
(
   code_languages_id  numeric(22)    NOT NULL,
   name               varchar(255),
   locale_name        varchar(255)
);

ALTER TABLE amr.amr_code_languages
  ADD CONSTRAINT pk_code_languages PRIMARY KEY (code_languages_id);

COMMENT ON TABLE amr.amr_code_languages IS 'Kód nyelvi tábla';
COMMENT ON COLUMN amr.amr_code_languages.code_languages_id IS 'Egyedi azonosító';
COMMENT ON COLUMN amr.amr_code_languages.name IS 'Nyelv neve';
COMMENT ON COLUMN amr.amr_code_languages.locale_name IS 'Nyelv lokális azonosítója';

GRANT DELETE, UPDATE, SELECT, INSERT ON amr.amr_code_languages TO methodus_proxy;
GRANT UPDATE, DELETE, SELECT, INSERT ON amr.amr_code_languages TO amr_proxy;
GRANT REFERENCES, SELECT, TRIGGER, DELETE, TRUNCATE, INSERT, UPDATE ON amr.amr_code_languages TO amr;
GRANT SELECT ON amr.amr_code_languages TO amr_db_readonly;


CREATE TABLE amr.amr_code_values
(
   lang_fk  numeric(22)     NOT NULL,
   code_fk  numeric(22)     NOT NULL,
   value    varchar(4000)
);

ALTER TABLE amr.amr_code_values
  ADD CONSTRAINT pk_code_values PRIMARY KEY (lang_fk, code_fk);

COMMENT ON TABLE amr.amr_code_values IS 'Kód értékek';
COMMENT ON COLUMN amr.amr_code_values.lang_fk IS 'Kód nyelvi azonosító';
COMMENT ON COLUMN amr.amr_code_values.code_fk IS 'Kód azonosító';
COMMENT ON COLUMN amr.amr_code_values.value IS 'Érték';

GRANT DELETE, SELECT, UPDATE, INSERT ON amr.amr_code_values TO methodus_proxy;
GRANT UPDATE, DELETE, SELECT, INSERT ON amr.amr_code_values TO amr_proxy;
GRANT REFERENCES, SELECT, TRIGGER, DELETE, TRUNCATE, INSERT, UPDATE ON amr.amr_code_values TO amr;
GRANT SELECT ON amr.amr_code_values TO methodus;
GRANT SELECT ON amr.amr_code_values TO amr_db_readonly;


ALTER TABLE amr_code_values
  ADD CONSTRAINT fk_amr_code_values_code FOREIGN KEY (code_fk)
  REFERENCES amr.amr_code (code_id) 
  ON UPDATE NO ACTION
  ON DELETE NO ACTION;

ALTER TABLE amr_code_values
  ADD CONSTRAINT fk_amr_code_languages FOREIGN KEY (lang_fk)
  REFERENCES amr.amr_code_languages (code_languages_id) 
  ON UPDATE NO ACTION
  ON DELETE NO ACTION;


