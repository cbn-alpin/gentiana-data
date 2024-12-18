-- ⚠ Copy and rename this file without ".sample." part.
-- Use it in your downloaded archive in the data/raw/ directory.

BEGIN;

\echo '-------------------------------------------------------------------------------'
\echo 'Finalize integration of users in GN database'

\echo '-------------------------------------------------------------------------------'
\echo 'Updating pre-existing users'
UPDATE utilisateurs.t_roles SET
    id_organisme = utilisateurs.get_id_organism_by_uuid('<uuid>')
WHERE identifiant = '<pre-existing-user-id>';

\echo '-------------------------------------------------------------------------------'
\echo 'Adding users to the Administrators group'
INSERT INTO utilisateurs.cor_roles (
    id_role_groupe,
    id_role_utilisateur
)
    SELECT
        utilisateurs.get_id_group_by_name('Administrateurs'),
        id_role
    FROM utilisateurs.t_roles
    WHERE email IN (
            'firstname.lastname1@example.com',
            'firstname.lastname2@example.com'
        )
        AND identifiant IS NOT NULL
ON CONFLICT DO NOTHING ;

\echo '-------------------------------------------------------------------------------'
\echo 'Adding users to the Agents group'
INSERT INTO utilisateurs.cor_roles (
    id_role_groupe,
    id_role_utilisateur
)
    SELECT
        utilisateurs.get_id_group_by_name('Agents'),
        id_role
    FROM utilisateurs.t_roles
    WHERE identifiant IS NOT NULL
        AND email IS NOT NULL
        AND email ILIKE '%@example.com'
ON CONFLICT DO NOTHING ;

\echo '-------------------------------------------------------------------------------'
\echo 'Adding users to the Validators group'
INSERT INTO utilisateurs.cor_roles (
    id_role_groupe,
    id_role_utilisateur
)
    SELECT
        utilisateurs.get_id_group_by_name('Validateurs'), -- Validateurs
        id_role
    FROM utilisateurs.t_roles
    WHERE email IN (
            'firstname.lastname3@example.com',
            'firstname.lastname4@example.com',
            'firstname.lastname5@example.com'
        )
        AND identifiant IS NOT NULL
ON CONFLICT DO NOTHING ;

\echo '-------------------------------------------------------------------------------'
\echo 'Adding users to the Datamanagers group'
INSERT INTO utilisateurs.cor_roles (
    id_role_groupe,
    id_role_utilisateur
)
    SELECT
        utilisateurs.get_id_group_by_name('Datamanagers'),
        id_role
    FROM utilisateurs.t_roles
    WHERE email IN (
            'firstname.lastname7@example.com',
            'firstname.lastname8@example.com',
            'firstname.lastname9@example.com'
        )
        AND identifiant IS NOT NULL
ON CONFLICT DO NOTHING ;

\echo '-------------------------------------------------------------------------------'
\echo 'Adding users to the Partners group'
INSERT INTO utilisateurs.cor_roles (
    id_role_groupe,
    id_role_utilisateur
)
    SELECT
        utilisateurs.get_id_group_by_name('Partenaires'),
        id_role
    FROM utilisateurs.t_roles
    WHERE email IS NOT NULL
        AND identifiant IS NOT NULL
        AND email NOT ILIKE '%@example.com'
ON CONFLICT DO NOTHING ;

\echo '-------------------------------------------------------------------------------'
\echo 'Adding users to the Observers group'
INSERT INTO utilisateurs.cor_roles (
    id_role_groupe,
    id_role_utilisateur
)
    SELECT
        utilisateurs.get_id_role_by_uuid('<uuid-observers>'), -- Observers Group
        id_role
    FROM utilisateurs.t_roles
    WHERE email IS NULL
        AND identifiant IS NULL
\echo 'Finalize integration of users in GN database'

\echo '----------------------------------------------------------------------------'
\echo 'Links datasets to module Occtax'
-- Enables selection of datasets on module Occtax for data entry tests
-- TO DO: Remove this part after data is integrated into Occtax

INSERT INTO gn_commons.cor_module_dataset (
	id_module,
	id_dataset
)
	SELECT
		gn_commons.get_id_module_bycode('OCCTAX'),
		id_dataset
	FROM gn_meta.t_datasets
ON CONFLICT DO NOTHING ;

\echo '----------------------------------------------------------------------------'
\echo 'Links datasets to module OccHab'
-- Enables selection of datasets on module Occtax for data entry tests
-- TODO: Remove this part after data is integrated into Occtax
INSERT INTO gn_commons.cor_module_dataset (
    id_module,
    id_dataset
)
    SELECT
        gn_commons.get_id_module_bycode('OCCHAB'),
        d.id_dataset
    FROM gn_meta.t_datasets AS d
        JOIN gn_meta.cor_dataset_actor AS cda
            ON d.id_dataset = cda.id_dataset
    WHERE d."active" = TRUE
        AND cda.id_nomenclature_actor_role = ref_nomenclatures.get_id_nomenclature('ROLE_ACTEUR', '6') -- Producteur
        AND cda.id_organism = utilisateurs.get_id_organism_by_uuid('<your-organism-uuid>') -- My organism;
ON CONFLICT DO NOTHING ;

\echo '----------------------------------------------------------------------------'
\echo 'COMMIT if all is ok:'
COMMIT;
