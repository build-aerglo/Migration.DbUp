UPDATE business b
SET review_count = (
    SELECT COUNT(*)
    FROM review r
    WHERE r.business_id = b.id
      AND r.status = 'APPROVED'
      AND r.is_verification_pending = FALSE
);