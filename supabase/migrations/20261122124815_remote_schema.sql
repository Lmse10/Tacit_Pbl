SET local check_function_bodies = off;

CREATE TABLE "public"."business_members" (
  "id"          uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "business_id" uuid                     NOT NULL,
  "user_id"     uuid                     NOT NULL,
  "role"        text                     NOT NULL,
  "joined_at"   timestamp with time zone DEFAULT now(),
  CONSTRAINT "business_members_business_id_user_id_key" UNIQUE (business_id, user_id),
  CONSTRAINT "business_members_pkey" PRIMARY KEY (id),
  CONSTRAINT "business_members_role_check" CHECK ((role = ANY (ARRAY['owner'::text, 'admin'::text, 'successor'::text])))
);

ALTER TABLE "public"."business_members"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."businesses" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "name"          text                     NOT NULL,
  "business_type" text,
  "description"   text,
  "created_by"    uuid,
  "created_at"    timestamp with time zone DEFAULT now(),
  CONSTRAINT "businesses_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."businesses"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."knowledge_records" (
  "id"                  uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "business_id"         uuid                     NOT NULL,
  "source_id"           uuid,
  "category"            text,
  "title"               text,
  "decision"            text,
  "reason"              text,
  "condition_text"      text,
  "exception_text"      text,
  "previous_experience" text,
  "risk"                text,
  "advice"              text,
  "related_entity"      text,
  "verification_status" text                     NOT NULL DEFAULT 'pending'::text,
  "approved_by"         uuid,
  "approved_at"         timestamp with time zone,
  "created_at"          timestamp with time zone DEFAULT now(),
  "updated_at"          timestamp with time zone DEFAULT now(),
  CONSTRAINT "knowledge_records_pkey" PRIMARY KEY (id),
  CONSTRAINT "knowledge_records_verification_status_check" CHECK ((verification_status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])))
);

ALTER TABLE "public"."knowledge_records"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."knowledge_sources" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "business_id"  uuid                     NOT NULL,
  "submitted_by" uuid,
  "source_type"  text                     NOT NULL,
  "raw_text"     text,
  "file_path"    text,
  "created_at"   timestamp with time zone DEFAULT now(),
  CONSTRAINT "knowledge_sources_pkey" PRIMARY KEY (id),
  CONSTRAINT "knowledge_sources_source_type_check" CHECK ((source_type = ANY (ARRAY['text'::text, 'voice'::text, 'document'::text])))
);

ALTER TABLE "public"."knowledge_sources"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."knowledge_versions" (
  "id"                  uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "knowledge_record_id" uuid                     NOT NULL,
  "version_number"      integer                  NOT NULL,
  "record_snapshot"     jsonb                    NOT NULL,
  "changed_by"          uuid,
  "change_reason"       text,
  "created_at"          timestamp with time zone DEFAULT now(),
  CONSTRAINT "knowledge_versions_knowledge_record_id_version_number_key" UNIQUE (knowledge_record_id, version_number),
  CONSTRAINT "knowledge_versions_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."knowledge_versions"
  ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.can_manage_business (
  target_business_id uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
    select exists (
        select 1
        from public.business_members bm
        where bm.business_id = target_business_id
        and bm.user_id = (select auth.uid())
        and bm.role in ('owner', 'admin')
    );
$function$;

CREATE OR REPLACE FUNCTION public.is_business_member (
  target_business_id uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
    select exists (
        select 1
        from public.business_members bm
        where bm.business_id = target_business_id
        and bm.user_id = (select auth.uid())
    );
$function$;

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
  RETURNS event_trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'pg_catalog'
  AS $function$
DECLARE
  cmd record;
  tbl name;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        SELECT c.relname INTO tbl FROM pg_catalog.pg_class c WHERE c.oid = cmd.objid;
        EXECUTE format('alter table if exists %I.%I enable row level security', cmd.schema_name, tbl);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$;

ALTER TABLE "public"."business_members"
  ADD CONSTRAINT "business_members_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."businesses"
  ADD CONSTRAINT "businesses_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id);

ALTER TABLE "public"."business_members"
  ADD CONSTRAINT "business_members_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."knowledge_records"
  ADD CONSTRAINT "knowledge_records_approved_by_fkey" FOREIGN KEY (approved_by) REFERENCES auth.users(id);

ALTER TABLE "public"."knowledge_records"
  ADD CONSTRAINT "knowledge_records_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."knowledge_sources"
  ADD CONSTRAINT "knowledge_sources_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."knowledge_records"
  ADD CONSTRAINT "knowledge_records_source_id_fkey" FOREIGN KEY (source_id) REFERENCES public.knowledge_sources(id) ON DELETE SET NULL;

ALTER TABLE "public"."knowledge_sources"
  ADD CONSTRAINT "knowledge_sources_submitted_by_fkey" FOREIGN KEY (submitted_by) REFERENCES auth.users(id);

ALTER TABLE "public"."knowledge_versions"
  ADD CONSTRAINT "knowledge_versions_changed_by_fkey" FOREIGN KEY (changed_by) REFERENCES auth.users(id);

ALTER TABLE "public"."knowledge_versions"
  ADD CONSTRAINT "knowledge_versions_knowledge_record_id_fkey" FOREIGN KEY (knowledge_record_id) REFERENCES public.knowledge_records(id) ON DELETE CASCADE;

CREATE POLICY "Members can view business members" ON "public"."business_members"
  FOR SELECT
  TO "authenticated"
  USING (public.is_business_member(business_id));

CREATE POLICY "Members can view businesses" ON "public"."businesses"
  FOR SELECT
  TO "authenticated"
  USING (public.is_business_member(id));

CREATE POLICY "Managers can add knowledge" ON "public"."knowledge_records"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (public.can_manage_business(business_id));

CREATE POLICY "Managers can update knowledge" ON "public"."knowledge_records"
  FOR UPDATE
  TO "authenticated"
  USING (public.can_manage_business(business_id))
  WITH CHECK (public.can_manage_business(business_id));

CREATE POLICY "Members can view approved knowledge" ON "public"."knowledge_records"
  FOR SELECT
  TO "authenticated"
  USING ((public.is_business_member(business_id) AND ((verification_status = 'approved'::text) OR public.can_manage_business(business_id))));

CREATE POLICY "Managers can add sources" ON "public"."knowledge_sources"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((public.can_manage_business(business_id) AND (submitted_by = ( SELECT auth.uid() AS uid))));

CREATE POLICY "Members can view sources" ON "public"."knowledge_sources"
  FOR SELECT
  TO "authenticated"
  USING (public.is_business_member(business_id));

CREATE POLICY "Managers can add knowledge versions" ON "public"."knowledge_versions"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.knowledge_records kr
  WHERE ((kr.id = knowledge_versions.knowledge_record_id) AND public.can_manage_business(kr.business_id)))));

CREATE POLICY "Members can view knowledge versions" ON "public"."knowledge_versions"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.knowledge_records kr
  WHERE ((kr.id = knowledge_versions.knowledge_record_id) AND public.is_business_member(kr.business_id)))));

CREATE EVENT TRIGGER "ensure_rls"
  ON ddl_command_end
  WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
  EXECUTE FUNCTION "public"."rls_auto_enable"();

REVOKE ALL ON FUNCTION "public"."can_manage_business"(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."can_manage_business"(uuid) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."can_manage_business"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."can_manage_business"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."can_manage_business"(uuid) TO "service_role";

REVOKE ALL ON FUNCTION "public"."is_business_member"(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."is_business_member"(uuid) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."is_business_member"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."is_business_member"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."is_business_member"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."rls_auto_enable"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."rls_auto_enable"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."rls_auto_enable"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."rls_auto_enable"() TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."business_members" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."business_members" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."business_members" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."business_members" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."businesses" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."businesses" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."businesses" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."businesses" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."knowledge_records" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."knowledge_records" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."knowledge_records" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."knowledge_records" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."knowledge_sources" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."knowledge_sources" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."knowledge_sources" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."knowledge_sources" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."knowledge_versions" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."knowledge_versions" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."knowledge_versions" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."knowledge_versions" TO "service_role";

