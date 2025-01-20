BEGIN;

\echo '-------------------------------------------------------------------------------'
\echo 'Finalize integration of GN database'

\echo '-------------------------------------------------------------------------------'
\echo 'Add unique index on t_roles.email field'
ALTER TABLE utilisateurs.t_roles DROP CONSTRAINT IF EXISTS unique_email;
ALTER TABLE utilisateurs.t_roles ADD CONSTRAINT unique_email UNIQUE (email);

\echo '-------------------------------------------------------------------------------'
\echo 'Add an unique index on the t_roles.identifier field'
ALTER TABLE utilisateurs.t_roles DROP CONSTRAINT IF EXISTS unique_identifiant;
ALTER TABLE utilisateurs.t_roles ADD CONSTRAINT unique_identifiant UNIQUE (identifiant);

\echo '-------------------------------------------------------------------------------'
\echo 'Changing the names of default groups'
UPDATE utilisateurs.t_roles SET
    nom_role = 'Agents'
WHERE id_role = 1 AND groupe = TRUE;
UPDATE utilisateurs.t_roles SET
    nom_role = 'Administrateurs'
WHERE id_role = 2 AND groupe = TRUE;

\echo '-------------------------------------------------------------------------------'
\echo 'Removing unnecessary example users'
DELETE FROM utilisateurs.cor_role_liste crl
USING utilisateurs.t_roles tr
WHERE (crl.id_role = 4 AND tr.identifiant = 'agent')
    OR (crl.id_role = 6 AND tr.identifiant = 'pierre.paul')
    OR (crl.id_role = 7 AND tr.identifiant = 'validateur');

DELETE FROM utilisateurs.t_roles
WHERE (id_role = 4 AND identifiant = 'agent')
    OR (id_role = 6 AND identifiant = 'pierre.paul')
    OR (id_role = 7 AND identifiant = 'validateur');

\echo '-------------------------------------------------------------------------------'
\echo 'Removing unnecessary sample organisms'

DELETE FROM utilisateurs.bib_organismes
WHERE (id_organisme = 1 AND nom_organisme = 'ma structure test');

\echo '-------------------------------------------------------------------------------'
\echo 'Change on users'
UPDATE utilisateurs.t_roles SET
    prenom_role = 'Administrateur',
    nom_role = 'GÉNÉRAL',
    remarques='Mise à jour installation.',
    pass = NULL,
    pass_plus = :'passAdmin'
WHERE id_role = 3 AND identifiant = 'admin';
UPDATE utilisateurs.t_roles SET
    id_role = 4,
    identifiant = 'partner-test',
    prenom_role = 'Partenaire',
    nom_role = 'TEST',
    email = 'adminsys+partner@cbn-alpin.fr',
    desc_role = 'Compte partenaire.',
    remarques = 'Compte partenaire de test.',
    pass = NULL,
    pass_plus = :'passPartner'
WHERE id_role = 5 AND identifiant = 'partenaire' ;

\echo '-------------------------------------------------------------------------------'
\echo 'Update the primary key sequence of t_roles'
SELECT SETVAL(
    pg_get_serial_sequence('utilisateurs.t_roles', 'id_role'),
    COALESCE(MAX(id_role) + 1, 1),
    FALSE
)
FROM utilisateurs.t_roles;

\echo '-------------------------------------------------------------------------------'
\echo 'Adding additional groups'
INSERT INTO utilisateurs.t_roles (
    nom_role,
    groupe,
    uuid_role,
    desc_role,
    remarques
) VALUES (
    'Observateurs',
    TRUE,
    'e944e966-b85f-44c8-acb7-941f6a74ba37',
    'Rassemble tous les observateurs sans accès.',
    'Groupe des observateurs sans accès à GeoNature.'
),
(
    'Partenaires',
    TRUE,
    'cceb3beb-1891-42e9-b01e-ef7a59ad461a',
    'Tous les utilisateurs externes au CBNA. Accès en lecture et écriture uniquement à leurs données dans tous les modules.',
    'Groupe des utilisateurs avec des droits limités en consultation et édition.'
),
(
    'Validateurs',
    TRUE,
    'dd04b9c2-eb93-47b4-80f5-df280b019c9c',
    'Tous les agents du service Connaissance.',
    'Groupe des utilisateurs avec des droits de validation taxonomique.'
),
(
    'Datamanagers',
    TRUE,
    'b259e9a6-136e-4bf9-a0d7-ada2dde7642c',
    'Tous les gestionnaire de données.',
    'Groupe des utilisateurs avec des droits sur les exports et imports.'
)
ON CONFLICT DO NOTHING ;

\echo '-------------------------------------------------------------------------------'
\echo 'Configuration of the Admin group for GeoNature'
INSERT INTO utilisateurs.cor_profil_for_app (
    id_profil,
    id_application
) VALUES (
    (SELECT id_profil FROM utilisateurs.t_profils WHERE nom_profil = 'Administrateur'),
    (SELECT id_application FROM utilisateurs.t_applications WHERE code_application = 'GN')
)
ON CONFLICT DO NOTHING ;

\echo '-------------------------------------------------------------------------------'
\echo 'Association of groups to profiles for applications (GeoNature, TaxHub and UsersHub)'
INSERT INTO utilisateurs.cor_role_app_profil (
    id_role,
    id_application,
    id_profil
) VALUES (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    (SELECT id_application FROM utilisateurs.t_applications WHERE code_application = 'GN'),
    (SELECT id_profil FROM utilisateurs.t_profils WHERE nom_profil = 'Administrateur')
), (
    utilisateurs.get_id_group_by_name('Validateurs'),
    (SELECT id_application FROM utilisateurs.t_applications WHERE code_application = 'GN'),
    (SELECT id_profil FROM utilisateurs.t_profils WHERE nom_profil = 'Lecteur')
), (
    utilisateurs.get_id_group_by_name('Partenaires'),
    (SELECT id_application FROM utilisateurs.t_applications WHERE code_application = 'GN'),
    (SELECT id_profil FROM utilisateurs.t_profils WHERE nom_profil = 'Lecteur')
), (
    utilisateurs.get_id_group_by_name('Datamanagers'),
    (SELECT id_application FROM utilisateurs.t_applications WHERE code_application = 'GN'),
    (SELECT id_profil FROM utilisateurs.t_profils WHERE nom_profil = 'Lecteur')
)
ON CONFLICT DO NOTHING ;


\echo '-------------------------------------------------------------------------------'
\echo 'Add utility functions for permissions'

CREATE OR REPLACE FUNCTION gn_permissions.get_id_action_by_code(actionCode VARCHAR)
 RETURNS INTEGER
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
    -- Function which return the id_action of an action by its code
    DECLARE idAction INTEGER;

    BEGIN
        SELECT INTO idAction ba.id_action
        FROM gn_permissions.bib_actions AS ba
        WHERE ba.code_action = actionCode ;

        RETURN idAction ;
    END;
$function$
;


\echo '-------------------------------------------------------------------------------'
\echo 'Adding permissions'
INSERT INTO gn_permissions.t_permissions (
    id_role,
    id_action,
    id_module,
    id_object,
    scope_value
) VALUES (
    utilisateurs.get_id_group_by_name('Agents'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('METADATA'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Agents'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('METADATA'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Agents'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('SYNTHESE'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Agents'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('SYNTHESE'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Agents'),
    gn_permissions.get_id_action_by_code('C'), -- Créer (C)
    gn_commons.get_id_module_bycode('OCCTAX'),
    gn_permissions.get_id_object('ALL'),
    2
), (
    utilisateurs.get_id_group_by_name('Agents'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('OCCTAX'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Agents'),
    gn_permissions.get_id_action_by_code('U'), -- Mettre à jour (U)
    gn_commons.get_id_module_bycode('OCCTAX'),
    gn_permissions.get_id_object('ALL'),
    2
), (
    utilisateurs.get_id_group_by_name('Agents'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('OCCTAX'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Agents'),
    gn_permissions.get_id_action_by_code('D'), -- Supprimer (D)
    gn_commons.get_id_module_bycode('OCCTAX'),
    gn_permissions.get_id_object('ALL'),
    1
), (
    utilisateurs.get_id_group_by_name('Agents'),
    gn_permissions.get_id_action_by_code('C'), -- Créer (C)
    gn_commons.get_id_module_bycode('OCCHAB'),
    gn_permissions.get_id_object('ALL'),
    2
), (
    utilisateurs.get_id_group_by_name('Agents'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('OCCHAB'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Agents'),
    gn_permissions.get_id_action_by_code('U'), -- Mettre à jour (U)
    gn_commons.get_id_module_bycode('OCCHAB'),
    gn_permissions.get_id_object('ALL'),
    2
), (
    utilisateurs.get_id_group_by_name('Agents'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('OCCHAB'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Agents'),
    gn_permissions.get_id_action_by_code('D'), -- Supprimer (D)
    gn_commons.get_id_module_bycode('OCCHAB'),
    gn_permissions.get_id_object('ALL'),
    1
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('C'), -- Créer (C)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('NOMENCLATURES'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('C'), -- Créer (C)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('MOBILE_APPS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('C'), -- Créer (C)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('ADDITIONAL_FIELDS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('C'), -- Créer (C)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('NOTIFICATIONS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('C'), -- Créer (C)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('PERMISSIONS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('NOMENCLATURES'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('PERMISSIONS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('NOTIFICATIONS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('ADDITIONAL_FIELDS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('MOBILE_APPS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('MODULES'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('U'), -- Mettre à jour (U)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('PERMISSIONS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('U'), -- Mettre à jour (U)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('MODULES'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('U'), -- Mettre à jour (U)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('ADDITIONAL_FIELDS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('U'), -- Mettre à jour (U)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('MOBILE_APPS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('U'), -- Mettre à jour (U)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('NOMENCLATURES'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('U'), -- Mettre à jour (U)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('NOTIFICATIONS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('MODULES'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('NOTIFICATIONS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('NOMENCLATURES'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('PERMISSIONS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('ADDITIONAL_FIELDS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('MOBILE_APPS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('D'), -- Supprimer (D)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('NOMENCLATURES'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('D'), -- Supprimer (D)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('NOTIFICATIONS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('D'), -- Supprimer (D)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('ADDITIONAL_FIELDS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('D'), -- Supprimer (D)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('PERMISSIONS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('D'), -- Supprimer (D)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('MOBILE_APPS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('C'), -- Créer (C)
    gn_commons.get_id_module_bycode('METADATA'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('METADATA'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('U'), -- Mettre à jour (U)
    gn_commons.get_id_module_bycode('METADATA'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('METADATA'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('D'), -- Supprimer (D)
    gn_commons.get_id_module_bycode('METADATA'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('SYNTHESE'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('SYNTHESE'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('C'), -- Créer (C)
    gn_commons.get_id_module_bycode('OCCTAX'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('OCCTAX'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('U'), -- Mettre à jour (U)
    gn_commons.get_id_module_bycode('OCCTAX'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('OCCTAX'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('D'), -- Supprimer (D)
    gn_commons.get_id_module_bycode('OCCTAX'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('C'), -- Créer (C)
    gn_commons.get_id_module_bycode('OCCHAB'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('OCCHAB'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('U'), -- Mettre à jour (U)
    gn_commons.get_id_module_bycode('OCCHAB'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('OCCHAB'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('D'), -- Supprimer (D)
    gn_commons.get_id_module_bycode('OCCHAB'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Administrateurs'),
    gn_permissions.get_id_action_by_code('C'), -- Créer (C)
    gn_commons.get_id_module_bycode('VALIDATION'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Partenaires'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('METADATA'),
    gn_permissions.get_id_object('ALL'),
    1
), (
    utilisateurs.get_id_group_by_name('Partenaires'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('METADATA'),
    gn_permissions.get_id_object('ALL'),
    1
), (
    utilisateurs.get_id_group_by_name('Partenaires'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('SYNTHESE'),
    gn_permissions.get_id_object('ALL'),
    1
), (
    utilisateurs.get_id_group_by_name('Partenaires'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('SYNTHESE'),
    gn_permissions.get_id_object('ALL'),
    1
), (
    utilisateurs.get_id_group_by_name('Partenaires'),
    gn_permissions.get_id_action_by_code('C'), -- Créer (C)
    gn_commons.get_id_module_bycode('OCCTAX'),
    gn_permissions.get_id_object('ALL'),
    1
), (
    utilisateurs.get_id_group_by_name('Partenaires'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('OCCTAX'),
    gn_permissions.get_id_object('ALL'),
    1
), (
    utilisateurs.get_id_group_by_name('Partenaires'),
    gn_permissions.get_id_action_by_code('U'), -- Mettre à jour (U)
    gn_commons.get_id_module_bycode('OCCTAX'),
    gn_permissions.get_id_object('ALL'),
    1
), (
    utilisateurs.get_id_group_by_name('Partenaires'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('OCCTAX'),
    gn_permissions.get_id_object('ALL'),
    1
), (
    utilisateurs.get_id_group_by_name('Partenaires'),
    gn_permissions.get_id_action_by_code('D'), -- Supprimer (D)
    gn_commons.get_id_module_bycode('OCCTAX'),
    gn_permissions.get_id_object('ALL'),
    1
), (
    utilisateurs.get_id_group_by_name('Partenaires'),
    gn_permissions.get_id_action_by_code('C'), -- Créer (C)
    gn_commons.get_id_module_bycode('OCCHAB'),
    gn_permissions.get_id_object('ALL'),
    1
), (
    utilisateurs.get_id_group_by_name('Partenaires'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('OCCHAB'),
    gn_permissions.get_id_object('ALL'),
    1
), (
    utilisateurs.get_id_group_by_name('Partenaires'),
    gn_permissions.get_id_action_by_code('U'), -- Mettre à jour (U)
    gn_commons.get_id_module_bycode('OCCHAB'),
    gn_permissions.get_id_object('ALL'),
    1
), (
    utilisateurs.get_id_group_by_name('Partenaires'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('OCCHAB'),
    gn_permissions.get_id_object('ALL'),
    1
), (
    utilisateurs.get_id_group_by_name('Partenaires'),
    gn_permissions.get_id_action_by_code('D'), -- Supprimer (D)
    gn_commons.get_id_module_bycode('OCCHAB'),
    gn_permissions.get_id_object('ALL'),
    1
), (
    utilisateurs.get_id_group_by_name('Partenaires'),
    gn_permissions.get_id_action_by_code('C'), -- Créer (C)
    gn_commons.get_id_module_bycode('VALIDATION'),
    gn_permissions.get_id_object('ALL'),
    1
), (
    utilisateurs.get_id_group_by_name('Validateurs'), -- Validateurs
    gn_permissions.get_id_action_by_code('C'), -- Créer (C)
    gn_commons.get_id_module_bycode('VALIDATION'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Datamanagers'),
    gn_permissions.get_id_action_by_code('C'), -- Créer (C)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('NOTIFICATIONS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Datamanagers'),
    gn_permissions.get_id_action_by_code('C'), -- Créer (C)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('ADDITIONAL_FIELDS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Datamanagers'),
    gn_permissions.get_id_action_by_code('C'), -- Créer (C)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('NOMENCLATURES'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Datamanagers'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('NOMENCLATURES'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Datamanagers'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('NOTIFICATIONS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Datamanagers'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('ADDITIONAL_FIELDS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Datamanagers'),
    gn_permissions.get_id_action_by_code('U'), -- Mettre à jour (U)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('ADDITIONAL_FIELDS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Datamanagers'),
    gn_permissions.get_id_action_by_code('U'), -- Mettre à jour (U)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('NOTIFICATIONS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Datamanagers'),
    gn_permissions.get_id_action_by_code('U'), -- Mettre à jour (U)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('NOMENCLATURES'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Datamanagers'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('NOTIFICATIONS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Datamanagers'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('NOMENCLATURES'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Datamanagers'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('ADDITIONAL_FIELDS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Datamanagers'),
    gn_permissions.get_id_action_by_code('D'), -- Supprimer (D)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('NOTIFICATIONS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Datamanagers'),
    gn_permissions.get_id_action_by_code('D'), -- Supprimer (D)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('NOMENCLATURES'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Datamanagers'),
    gn_permissions.get_id_action_by_code('D'), -- Supprimer (D)
    gn_commons.get_id_module_bycode('ADMIN'),
    gn_permissions.get_id_object('ADDITIONAL_FIELDS'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Datamanagers'),
    gn_permissions.get_id_action_by_code('C'), -- Créer (C)
    gn_commons.get_id_module_bycode('METADATA'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Datamanagers'),
    gn_permissions.get_id_action_by_code('R'), -- Lire (R)
    gn_commons.get_id_module_bycode('METADATA'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Datamanagers'),
    gn_permissions.get_id_action_by_code('U'), -- Mettre à jour (U)
    gn_commons.get_id_module_bycode('METADATA'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Datamanagers'),
    gn_permissions.get_id_action_by_code('E'), -- Exporter (E)
    gn_commons.get_id_module_bycode('METADATA'),
    gn_permissions.get_id_object('ALL'),
    NULL
), (
    utilisateurs.get_id_group_by_name('Datamanagers'),
    gn_permissions.get_id_action_by_code('D'), -- Supprimer (D)
    gn_commons.get_id_module_bycode('METADATA'),
    gn_permissions.get_id_object('ALL'),
    NULL
)
ON CONFLICT DO NOTHING ;


-- \echo '-------------------------------------------------------------------------------'
-- \echo 'Use this to insert a new permission if needed:'

-- SELECT
--      CONCAT(
--          e'(\n',
--          e'\tutilisateurs.get_id_role_by_uuid(''', r.uuid_role,	'''), -- ', r.nom_role, e'\n',
--          e'\tgn_permissions.get_id_action_by_code(''', a.code_action, '''), -- ', a.description_action, e'\n',
--          e'\tgn_commons.get_id_module_bycode(''', m.module_code, '''),', e'\n',
--          e'\tgn_permissions.get_id_object(''', o.code_object, '''),', e'\n',
--          e'\t', COALESCE(p.scope_value::VARCHAR, 'NULL'), e'\n',
--          e'),\n'
--      )
-- FROM gn_permissions.t_permissions AS p
--      JOIN gn_permissions.bib_actions AS a
--          ON p.id_action = a.id_action
--      JOIN gn_permissions.t_objects AS o
--          ON p.id_object = o.id_object
--      JOIN gn_commons.t_modules AS m
--          ON p.id_module = m.id_module
--      JOIN utilisateurs.t_roles AS r
--          ON p.id_role = r.id_role
-- ORDER BY p.id_role, p.id_module, p.id_action ;

\echo '-------------------------------------------------------------------------------'
\echo 'Add study perimeter as a type and its data for use with the Atlas'

INSERT INTO ref_geo.bib_areas_types (
    type_name,
    type_code
) VALUES (
    'Périmètres d''étude',
    'PE'
)
ON CONFLICT DO NOTHING ;

INSERT INTO ref_geo.l_areas (
    id_type,
    area_name,
    area_code,
    geom,
    geom_4326,
    centroid,
    "enable"
)
SELECT
    ref_geo.get_id_area_type_by_code('PE'),
    'Périmètre d''étude de Gentiana',
    'PE-GENTIANA',
    a.geom,
    a.geom_4326,
    a.centroid,
    TRUE
FROM ref_geo.l_areas AS a
WHERE a.id_type = ref_geo.get_id_area_type_by_code('DEP')
    AND a.area_code = '38'
ON CONFLICT DO NOTHING ;

\echo '----------------------------------------------------------------------------'
\echo 'COMMIT if all is ok:'
COMMIT;

