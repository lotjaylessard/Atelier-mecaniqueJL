-- Protection des historiques de paiement, à tester dans TEST avant PROD.
CREATE OR REPLACE FUNCTION public.guard_garage_invoice_payments()
RETURNS trigger LANGUAGE plpgsql SET search_path TO '' AS $$
DECLARE old_i jsonb; new_i jsonb; p jsonb; old_count int; idx int; received numeric; total numeric; history numeric;
BEGIN
 IF NEW.data->'invoices' IS NOT DISTINCT FROM OLD.data->'invoices' THEN RETURN NEW; END IF;
 IF jsonb_typeof(NEW.data->'invoices') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Historique factures invalide'; END IF;
 FOR old_i IN SELECT value FROM jsonb_array_elements(COALESCE(OLD.data->'invoices','[]'::jsonb)) LOOP
  IF COALESCE((old_i->>'paidAmount')::numeric,0)<=0 AND jsonb_array_length(COALESCE(old_i->'payments','[]'::jsonb))=0 AND old_i->>'status' NOT IN ('paid','partial') THEN CONTINUE; END IF;
  SELECT count(*) INTO old_count FROM jsonb_array_elements(NEW.data->'invoices') x WHERE x->>'number'=old_i->>'number';
  IF old_count<>1 THEN RAISE EXCEPTION 'Facture avec paiements absente ou dupliquée'; END IF;
  SELECT x INTO new_i FROM jsonb_array_elements(NEW.data->'invoices') x WHERE x->>'number'=old_i->>'number';
  IF new_i IS NOT DISTINCT FROM old_i THEN CONTINUE; END IF;
  IF jsonb_typeof(new_i->'payments') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Historique paiements invalide'; END IF;
  old_count:=jsonb_array_length(COALESCE(old_i->'payments','[]'::jsonb));
  IF jsonb_array_length(new_i->'payments')<old_count THEN RAISE EXCEPTION 'Suppression paiement interdite'; END IF;
  FOR idx IN 0..old_count-1 LOOP
   IF new_i->'payments'->idx IS DISTINCT FROM old_i->'payments'->idx THEN RAISE EXCEPTION 'Modification paiement historique interdite'; END IF;
  END LOOP;
  IF old_i->>'status'='paid' THEN
   IF (new_i - ARRAY['archived','archivedDate','archivedAt','updatedAt']) IS DISTINCT FROM (old_i - ARRAY['archived','archivedDate','archivedAt','updatedAt']) THEN RAISE EXCEPTION 'Facture payée verrouillée'; END IF;
   CONTINUE;
  END IF;
  received:=(new_i->>'paidAmount')::numeric; total:=(new_i->>'total')::numeric;
  SELECT COALESCE(sum((value->>'amount')::numeric),0) INTO history FROM jsonb_array_elements(new_i->'payments');
  IF received IS NULL OR total IS NULL OR received<COALESCE((old_i->>'paidAmount')::numeric,0) OR abs(received-history)>0.009 OR received>total+0.009 THEN RAISE EXCEPTION 'Solde ou paiements incohérents'; END IF;
  IF new_i->>'status' NOT IN ('paid','partial') OR (new_i->>'status'='paid' AND abs(total-received)>0.009) OR (new_i->>'status'='partial' AND received>=total-0.009) THEN RAISE EXCEPTION 'Statut paiement incohérent'; END IF;
 END LOOP;
 FOR new_i IN SELECT value FROM jsonb_array_elements(NEW.data->'invoices') LOOP
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(COALESCE(OLD.data->'invoices','[]'::jsonb)) x WHERE x=new_i) THEN CONTINUE; END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(COALESCE(OLD.data->'invoices','[]'::jsonb)) x WHERE x->>'number'=new_i->>'number' AND x->>'status'='paid') THEN CONTINUE; END IF;
  IF COALESCE((new_i->>'paidAmount')::numeric,0)=0 AND COALESCE(jsonb_array_length(new_i->'payments'),0)=0 AND COALESCE(new_i->>'status','') NOT IN ('paid','partial') THEN CONTINUE; END IF;
  IF jsonb_typeof(new_i->'payments') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Historique paiements invalide'; END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(new_i->'payments') x WHERE (x->>'amount') IS NULL OR (x->>'amount')::numeric<=0) THEN RAISE EXCEPTION 'Montant paiement invalide'; END IF;
  received:=(new_i->>'paidAmount')::numeric; total:=(new_i->>'total')::numeric;
  SELECT COALESCE(sum((value->>'amount')::numeric),0) INTO history FROM jsonb_array_elements(new_i->'payments');
  IF received IS NULL OR total IS NULL OR received<0 OR total<0 OR abs(received-history)>0.009 OR received>total+0.009 THEN RAISE EXCEPTION 'Solde ou paiements incohérents'; END IF;
  IF COALESCE(new_i->>'status','') NOT IN ('paid','partial') OR (new_i->>'status'='paid' AND abs(total-received)>0.009) OR (new_i->>'status'='partial' AND (received<=0 OR received>=total-0.009)) THEN RAISE EXCEPTION 'Statut paiement incohérent'; END IF;
 END LOOP;
 RETURN NEW;
END $$;
CREATE TRIGGER guard_garage_invoice_payments_trigger BEFORE UPDATE ON public.garage_data FOR EACH ROW EXECUTE FUNCTION public.guard_garage_invoice_payments();
