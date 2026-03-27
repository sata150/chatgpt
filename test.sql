CREATE TABLE amr.amr_code_values
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


ALTER TABLE amr_code_values
  ADD CONSTRAINT fk_amr_code_languages FOREIGN KEY (lang_fk)
  REFERENCES amr.amr_code_languages (code_languages_id) 
  ON UPDATE NO ACTION
  ON DELETE NO ACTION;


-- SOFT DELETE SCRIPTEK (nincs fizikai törlés)
-- A "törlés" az amr.amr_code.valid_to mező lejáratásával történik.

-- MŰVELETTÍPUSOK:
-- D = soft delete (valid_to lejáratás)
-- I = insert (amr_code + amr_code_values hu/en)
-- U = update (soft delete + insert)
DO
$$
DECLARE
  v_rec            record;
  v_new_code_id    numeric(22);
  v_next_code_id   numeric(22);
  v_group_designation varchar(255);
  v_active_code_id numeric(22);
  v_current_value_hu varchar(4000);
  v_current_value_en varchar(4000);
  v_rows           integer;
  v_total_count    integer := 0;
  v_success_count  integer := 0;
  v_failed_count   integer := 0;
  v_error_text     text;
BEGIN
  SELECT COALESCE(MAX(code_id), 0)
    INTO v_next_code_id
    FROM amr.amr_code;
  RAISE NOTICE '[TRACE] INIT MAX(code_id) -> v_next_code_id=%', v_next_code_id;

  FOR v_rec IN
    SELECT
      t.op_type,
      t.code_group_fk,
      t.code,
      t.code_group_designation,
      t.check_value_hu,
      t.check_value_en,
      t.value_hu,
      t.value_en
      FROM (
        VALUES
          ('D'::char(1), 100::numeric(22), 'CODE_TO_DELETE'::varchar(255), 'Minta csoport'::varchar(255), 'Régi magyar érték'::varchar(4000), 'Old english value'::varchar(4000), NULL::varchar(4000), NULL::varchar(4000))
          -- INSERT példa:
          -- , ('I'::char(1), 200::numeric(22), 'CODE_NEW'::varchar(255), 'Új csoport'::varchar(255), NULL::varchar(4000), NULL::varchar(4000), 'Magyar érték'::varchar(4000), 'English value'::varchar(4000))
          -- UPDATE példa (soft delete + insert):
          -- , ('U'::char(1), 300::numeric(22), 'CODE_TO_UPDATE'::varchar(255), 'Frissítendő csoport'::varchar(255), 'Régi magyar érték'::varchar(4000), 'Old english value'::varchar(4000), 'Új magyar érték'::varchar(4000), 'New english value'::varchar(4000))
      ) AS t(op_type, code_group_fk, code, code_group_designation, check_value_hu, check_value_en, value_hu, value_en)
  LOOP
    v_total_count := v_total_count + 1;
    v_error_text := NULL;

    BEGIN
    RAISE NOTICE '[TRACE] START ROW op_type=%, code_group_fk=%, code=%, check_hu=%, check_en=%, new_hu=%, new_en=%',
      v_rec.op_type, v_rec.code_group_fk, v_rec.code, v_rec.check_value_hu, v_rec.check_value_en, v_rec.value_hu, v_rec.value_en;

    SELECT cg.designation
      INTO v_group_designation
      FROM amr.amr_code_group cg
     WHERE cg.code_group_id = v_rec.code_group_fk;
    RAISE NOTICE '[TRACE] SELECT code_group designation -> code_group_fk=%, designation=%',
      v_rec.code_group_fk, v_group_designation;

    IF v_group_designation IS NULL THEN
      RAISE EXCEPTION 'Nem létező code_group_fk: %', v_rec.code_group_fk;
    END IF;

    IF v_group_designation <> v_rec.code_group_designation THEN
      RAISE EXCEPTION
        'Eltérő code_group designation. code_group_fk=%, várt=%, kapott=%',
        v_rec.code_group_fk,
        v_rec.code_group_designation,
        v_group_designation;
    END IF;

    IF v_rec.op_type = 'D' THEN
      SELECT c.code_id
        INTO v_active_code_id
        FROM amr.amr_code c
       WHERE c.code_group_fk = v_rec.code_group_fk
         AND c.code = v_rec.code
         AND c.valid_to > CURRENT_DATE
       ORDER BY c.valid_from DESC NULLS LAST, c.code_id DESC
       LIMIT 1;
      RAISE NOTICE '[TRACE] SELECT active code (D) -> code_group_fk=%, code=%, active_code_id=%',
        v_rec.code_group_fk, v_rec.code, v_active_code_id;

      IF v_active_code_id IS NULL THEN
        RAISE EXCEPTION 'Nincs aktív rekord soft delete művelethez. code_group_fk=%, code=%',
          v_rec.code_group_fk, v_rec.code;
      END IF;

      SELECT
        MAX(CASE WHEN cv.lang_fk = 1 THEN cv.value END),
        MAX(CASE WHEN cv.lang_fk = 2 THEN cv.value END)
        INTO v_current_value_hu, v_current_value_en
        FROM amr.amr_code_values cv
       WHERE cv.code_fk = v_active_code_id;
      RAISE NOTICE '[TRACE] SELECT current values (D) -> code_id=%, hu=%, en=%',
        v_active_code_id, v_current_value_hu, v_current_value_en;

      IF v_rec.check_value_hu IS NOT NULL
         AND COALESCE(v_current_value_hu, '<NULL>') <> v_rec.check_value_hu THEN
        RAISE EXCEPTION
          'Eltérő HU kiinduló érték. code_group_fk=%, code=%, várt=%, kapott=%',
          v_rec.code_group_fk,
          v_rec.code,
          v_rec.check_value_hu,
          COALESCE(v_current_value_hu, '<NULL>');
      END IF;

      IF v_rec.check_value_en IS NOT NULL
         AND COALESCE(v_current_value_en, '<NULL>') <> v_rec.check_value_en THEN
        RAISE EXCEPTION
          'Eltérő EN kiinduló érték. code_group_fk=%, code=%, várt=%, kapott=%',
          v_rec.code_group_fk,
          v_rec.code,
          v_rec.check_value_en,
          COALESCE(v_current_value_en, '<NULL>');
      END IF;

      UPDATE amr.amr_code
         SET valid_to = CURRENT_DATE
       WHERE code_group_fk = v_rec.code_group_fk
         AND code = v_rec.code
         AND valid_to > CURRENT_DATE;
      GET DIAGNOSTICS v_rows = ROW_COUNT;
      RAISE NOTICE '[TRACE] UPDATE D soft delete -> rows=%', v_rows;

    ELSIF v_rec.op_type = 'I' THEN
      v_next_code_id := v_next_code_id + 1;
      v_new_code_id := v_next_code_id;
      RAISE NOTICE '[TRACE] I next code_id prepared -> %', v_new_code_id;

      INSERT INTO amr.amr_code (code_id, code_group_fk, code, valid_from, valid_to)
      VALUES (v_new_code_id, v_rec.code_group_fk, v_rec.code, CURRENT_DATE, DATE '9999-12-31');
      GET DIAGNOSTICS v_rows = ROW_COUNT;
      RAISE NOTICE '[TRACE] INSERT amr_code (I) -> rows=%, code_id=%', v_rows, v_new_code_id;

      INSERT INTO amr.amr_code_values (lang_fk, code_fk, value)
      VALUES (1, v_new_code_id, v_rec.value_hu);
      GET DIAGNOSTICS v_rows = ROW_COUNT;
      RAISE NOTICE '[TRACE] INSERT amr_code_values HU (I) -> rows=%, code_id=%, value=%',
        v_rows, v_new_code_id, v_rec.value_hu;

      INSERT INTO amr.amr_code_values (lang_fk, code_fk, value)
      VALUES (2, v_new_code_id, v_rec.value_en);
      GET DIAGNOSTICS v_rows = ROW_COUNT;
      RAISE NOTICE '[TRACE] INSERT amr_code_values EN (I) -> rows=%, code_id=%, value=%',
        v_rows, v_new_code_id, v_rec.value_en;

    ELSIF v_rec.op_type = 'U' THEN
      SELECT c.code_id
        INTO v_active_code_id
        FROM amr.amr_code c
       WHERE c.code_group_fk = v_rec.code_group_fk
         AND c.code = v_rec.code
         AND c.valid_to > CURRENT_DATE
       ORDER BY c.valid_from DESC NULLS LAST, c.code_id DESC
       LIMIT 1;
      RAISE NOTICE '[TRACE] SELECT active code (U) -> code_group_fk=%, code=%, active_code_id=%',
        v_rec.code_group_fk, v_rec.code, v_active_code_id;

      IF v_active_code_id IS NULL THEN
        RAISE EXCEPTION 'Nincs aktív rekord update művelethez. code_group_fk=%, code=%',
          v_rec.code_group_fk, v_rec.code;
      END IF;

      SELECT
        MAX(CASE WHEN cv.lang_fk = 1 THEN cv.value END),
        MAX(CASE WHEN cv.lang_fk = 2 THEN cv.value END)
        INTO v_current_value_hu, v_current_value_en
        FROM amr.amr_code_values cv
       WHERE cv.code_fk = v_active_code_id;
      RAISE NOTICE '[TRACE] SELECT current values (U) -> code_id=%, hu=%, en=%',
        v_active_code_id, v_current_value_hu, v_current_value_en;

      IF v_rec.check_value_hu IS NOT NULL
         AND COALESCE(v_current_value_hu, '<NULL>') <> v_rec.check_value_hu THEN
        RAISE EXCEPTION
          'Eltérő HU kiinduló érték. code_group_fk=%, code=%, várt=%, kapott=%',
          v_rec.code_group_fk,
          v_rec.code,
          v_rec.check_value_hu,
          COALESCE(v_current_value_hu, '<NULL>');
      END IF;

      IF v_rec.check_value_en IS NOT NULL
         AND COALESCE(v_current_value_en, '<NULL>') <> v_rec.check_value_en THEN
        RAISE EXCEPTION
          'Eltérő EN kiinduló érték. code_group_fk=%, code=%, várt=%, kapott=%',
          v_rec.code_group_fk,
          v_rec.code,
          v_rec.check_value_en,
          COALESCE(v_current_value_en, '<NULL>');
      END IF;

      UPDATE amr.amr_code
         SET valid_to = CURRENT_DATE
       WHERE code_group_fk = v_rec.code_group_fk
         AND code = v_rec.code
         AND valid_to > CURRENT_DATE;
      GET DIAGNOSTICS v_rows = ROW_COUNT;
      RAISE NOTICE '[TRACE] UPDATE U soft delete -> rows=%', v_rows;

      v_next_code_id := v_next_code_id + 1;
      v_new_code_id := v_next_code_id;
      RAISE NOTICE '[TRACE] U next code_id prepared -> %', v_new_code_id;

      INSERT INTO amr.amr_code (code_id, code_group_fk, code, valid_from, valid_to)
      VALUES (v_new_code_id, v_rec.code_group_fk, v_rec.code, CURRENT_DATE, DATE '9999-12-31');
      GET DIAGNOSTICS v_rows = ROW_COUNT;
      RAISE NOTICE '[TRACE] INSERT amr_code (U) -> rows=%, code_id=%', v_rows, v_new_code_id;

      INSERT INTO amr.amr_code_values (lang_fk, code_fk, value)
      VALUES (1, v_new_code_id, v_rec.value_hu);
      GET DIAGNOSTICS v_rows = ROW_COUNT;
      RAISE NOTICE '[TRACE] INSERT amr_code_values HU (U) -> rows=%, code_id=%, value=%',
        v_rows, v_new_code_id, v_rec.value_hu;

      INSERT INTO amr.amr_code_values (lang_fk, code_fk, value)
      VALUES (2, v_new_code_id, v_rec.value_en);
      GET DIAGNOSTICS v_rows = ROW_COUNT;
      RAISE NOTICE '[TRACE] INSERT amr_code_values EN (U) -> rows=%, code_id=%, value=%',
        v_rows, v_new_code_id, v_rec.value_en;

    ELSE
      RAISE EXCEPTION 'Ismeretlen művelettípus: % (engedélyezett: D, I, U)', v_rec.op_type;
    END IF;

    v_success_count := v_success_count + 1;
    RAISE NOTICE '[TRACE] END ROW op_type=%, code_group_fk=%, code=%, status=SUCCESS',
      v_rec.op_type, v_rec.code_group_fk, v_rec.code;
    EXCEPTION
      WHEN OTHERS THEN
        v_failed_count := v_failed_count + 1;
        v_error_text := SQLERRM;
        RAISE NOTICE '[TRACE] END ROW op_type=%, code_group_fk=%, code=%, status=FAILED, error=%',
          v_rec.op_type, v_rec.code_group_fk, v_rec.code, v_error_text;
    END;
  END LOOP;

  RAISE NOTICE '[TRACE] SCRIPT END summary -> total=%, success=%, failed=%',
    v_total_count, v_success_count, v_failed_count;
END;
$$;
