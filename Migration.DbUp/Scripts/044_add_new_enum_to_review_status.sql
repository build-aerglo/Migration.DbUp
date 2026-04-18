BEGIN;

-- 1. Drop the old constraint
ALTER TABLE review 
  DROP CONSTRAINT IF EXISTS chk_review_status;

-- 2. Add the new constraint but don't validate existing data yet
-- This prevents a long "Access Exclusive Lock" on large tables
ALTER TABLE review 
  ADD CONSTRAINT chk_review_status 
  CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'FLAGGED', 'AWAITING_MODERATION')) 
  NOT VALID;

-- 3. Validate it (Scan the table without blocking writes)
ALTER TABLE review 
  VALIDATE CONSTRAINT chk_review_status;

COMMIT;