----CREATING TABLE
CREATE TABLE novacare_claims_raw(
claim_id VARCHAR(50) PRIMARY KEY,
patient_id VARCHAR(50),
encounter_id VARCHAR(50),
provider_id VARCHAR(50),
provider_name VARCHAR(50),
department VARCHAR(50),
admission_date DATE,
discharge_date DATE,
claim_submission_date DATE,
icd10_primary VARCHAR(50),
icd10_description VARCHAR(50),
cpt_procedure INT,
billed_amount FLOAT,
allowed_amount FLOAT,
paid_amount FLOAT,
claim_status VARCHAR(50),
denial_reason VARCHAR(50),
payer_type VARCHAR(50),
claim_processing_days INT
);

SELECT *
FROM novacare_claims_raw

---DATA CLEANING

CREATE TABLE claims_clean AS
---Removing extra spaces
SELECT
    -- IDs (trim spaces)
    TRIM(claim_id) AS claim_id,
    TRIM(patient_id) AS patient_id,
    TRIM(encounter_id) AS encounter_id,
    TRIM(provider_id) AS provider_id,
	TRIM(provider_name) AS provider_name,
    TRIM(department) AS department,
	admission_date,
    discharge_date,
    claim_submission_date,
	TRIM(icd10_primary) AS icd10_primary,
	TRIM(icd10_description) AS icd10_description,
	cpt_procedure,
    billed_amount,
    allowed_amount,
    paid_amount,
	TRIM(claim_status) AS claim_status,
	TRIM(denial_reason) AS denial_reason,
	TRIM(payer_type) AS payer_type,
	claim_processing_days
FROM novacare_claims_raw
	
---Standardize casing for provider name
UPDATE claims_clean
SET provider_name = CASE 
    WHEN provider_id = 'P001' THEN 'Dr. Amara Osei'
	WHEN provider_id = 'P002' THEN 'Dr. Fatima Bello'
	WHEN provider_id = 'P003' THEN 'Dr. Chukwuemeka Eze'
    WHEN provider_id = 'P004' THEN 'Dr. Ngozi Adeyemi'
    WHEN provider_id = 'P005' THEN 'Dr. Kwame Mensah'
    WHEN provider_id = 'P006' THEN 'Dr. Aisha Kamara'
    WHEN provider_id = 'P007' THEN 'Dr. Emeka Nwosu'
    WHEN provider_id = 'P008' THEN 'Dr. Seun Afolabi'
    WHEN provider_id = 'P009' THEN 'Dr. Kofi Asante'
    WHEN provider_id = 'P010' THEN 'Dr. Yetunde Okafor'
    WHEN provider_id = 'P011' THEN 'Dr. Ibrahim Musa'
    WHEN provider_id = 'P012' THEN 'Dr. Chioma Obi'
   END
WHERE provider_id IN ('P001', 'P002', 'P003', 'P004', 'P005', 'P006', 'P007', 'P008', 'P009', 'P010', 'P011', 'P012');
---Standardize casing for department
UPDATE claims_clean
SET department = CASE 
    WHEN UPPER(department) LIKE 'CARDIO%' THEN 'Cardiology'
    WHEN UPPER(department) IN ('EMERG', 'ER') THEN 'Emergency'
    WHEN UPPER(department) IN ('GEN SURGERY', 'GEN. SURGERY') THEN 'General Surgery'
    WHEN UPPER(department) IN ('INT MEDICINE', 'INT. MED') THEN 'Internal Medicine'
    WHEN UPPER(department) IN ('NEURO', 'NEUROLOGY') THEN 'Neurology'
    WHEN UPPER(department) LIKE 'ONCO%' THEN 'Oncology'
    WHEN UPPER(department) LIKE 'PEDS%' THEN 'Pediatrics'
    WHEN UPPER(department) LIKE 'ORTHO%' THEN 'Orthopedics'
    ELSE INITCAP(department)
END;

---Standardize casing for icd10_description

UPDATE claims_clean
SET icd10_primary = REPLACE(icd10_primary, '.', '')
WHERE icd10_description IN ('Gastroenteritis', 'Viral Infection', 'Lung Cancer', 'Type 2 Diabetes Mellitus', 'Major Depressive Disorder', 'Essential Hypertension', 'Coronary Artery Disease', 'Cerebral Infarction', 'Pneumonia', 'COPD Exacerbation', 'Melena', 'Low Back Pain', 'Urinary Tract Infection', 'Femur Fracture', 'Single Liveborn');

---Standardize casing for claim_status

UPDATE claims_clean
SET claim_status = CASE 
    WHEN UPPER(TRIM(claim_status)) = 'PAID' THEN 'Paid'
    WHEN UPPER(TRIM(claim_status)) = 'DENIED' THEN 'Denied'
    WHEN UPPER(TRIM(claim_status)) = 'PENDING' THEN 'Pending'
    WHEN UPPER(TRIM(claim_status)) = 'APPEALED' THEN 'Appealed'
    ELSE INITCAP(TRIM(claim_status))
END;

---duplicates in encounter id
SELECT *
FROM claims_clean
WHERE encounter_id IN (
    SELECT encounter_id
    FROM claims_clean
    GROUP BY encounter_id
    HAVING COUNT(*) > 1
)
ORDER BY encounter_id, claim_submission_date;

---The duplicates in encounter_id were labelled as duplicate_claim in denial reason...Flagging that
ALTER TABLE claims_clean 
ADD COLUMN is_duplicate_claim INTEGER DEFAULT 0;

UPDATE claims_clean
SET is_duplicate_claim = 1
WHERE UPPER(denial_reason) = 'DUPLICATE CLAIM';

---Some patients have no billed amount and allowed amount, yet they had a paid amount, and the claim status is paid. 
---Creating a flagged column for these patients.

ALTER TABLE claims_clean 
ADD COLUMN paid_error INTEGER DEFAULT 0;

---Flagged patients

UPDATE claims_clean
SET paid_error = 1
WHERE (billed_amount IS NULL) 
AND (allowed_amount IS NULL)
AND paid_amount > 0;

---Claims submission date before discharge date

ALTER TABLE claims_clean 
ADD COLUMN claim_before_discharge INTEGER DEFAULT 0;

---Flag rows where the submission happened before discharge

UPDATE claims_clean
SET claim_before_discharge  = 1
WHERE claim_submission_date < discharge_date;

---Claims submission date before admission date

ALTER TABLE claims_clean 
ADD COLUMN claim_before_admission INTEGER DEFAULT 0;

---Flag rows where the submission happened before admission
UPDATE claims_clean
SET claim_before_discharge  = 1
WHERE claim_submission_date < admission_date;

---Calculate and update Length of Days (LOD) for submission

ALTER TABLE claims_clean 
ADD COLUMN days_to_submit INTEGER;

UPDATE claims_clean
SET days_to_submit = claim_submission_date - discharge_date;


---For patients whose claim was denied but denial_reason was null tag unknown
UPDATE claims_clean
SET denial_reason = 'Unknown'
WHERE claim_status = 'Denied' 
AND (denial_reason IS NULL OR TRIM(denial_reason) = '');

---Pending claim status
ALTER TABLE claims_clean 
ADD COLUMN is_pending INT

UPDATE claims_clean
SET is_pending = 1
WHERE (claim_status) = 'Pending';

---Removing the negative values in claim_processing days. 

UPDATE claims_clean
SET claim_processing_days = ABS(claim_processing_days)
WHERE claim_processing_days < 0;

---Dropping the flag earlier created for the negative values.
ALTER TABLE claims_clean 
DROP COLUMN negative_claim_processing_daysentry\\\;

---Replace null value in allowed amount with the value in paid amount, if present.
UPDATE claims_clean
SET allowed_amount = COALESCE(allowed_amount, paid_amount)
WHERE allowed_amount IS NULL;

---Replace null value in allowed amount with 0
UPDATE claims_clean
SET allowed_amount = 0
WHERE allowed_amount IS NULL;

---Replace null value in billed amount with 0
UPDATE claims_clean
SET billed_amount = 0
WHERE billed_amount IS NULL;

---Replace NULL payer type with unknown
UPDATE claims_clean
SET payer_type = 'Unknown'
WHERE payer_type IS NULL; 


SELECT*
FROM claims_clean


