begin;

truncate promo_code_usages, promo_codes, promotion_products, promotion_categories, promotions,
  order_items, orders, cart_items, carts, price_history, currencies, product_variants,
  product_categories, products, brands, categories, addresses, users restart identity cascade;

create or replace function pg_temp.rnd(k text, n int) returns int language sql immutable as
$$ select (('x' || substr(md5(k), 1, 8))::bit(32)::bigint % n)::int $$;

create temp table t_first_names (n int primary key, v text) on commit drop;
insert into t_first_names
select row_number() over (), v from unnest(array[
  'Alice','Louis','Emma','Gabriel','Jade','Léo','Louise','Raphaël','Chloé','Arthur',
  'Manon','Jules','Camille','Lucas','Inès','Hugo','Léa','Adam','Sarah','Nathan',
  'Zoé','Paul','Lina','Tom','Juliette','Théo','Clara','Noah','Anna','Mathis',
  'Margaux','Maël','Lou','Victor','Agathe','Antoine','Romane','Baptiste','Elsa','Maxime',
  'Pauline','Julien','Mathilde','Thomas','Céline','Nicolas','Élodie','Sébastien','Hélène','François']) v;

create temp table t_last_names (n int primary key, v text) on commit drop;
insert into t_last_names
select row_number() over (), v from unnest(array[
  'Martin','Bernard','Dubois','Thomas','Robert','Richard','Petit','Durand','Leroy','Moreau',
  'Simon','Laurent','Lefèvre','Michel','Garcia','David','Bertrand','Roux','Vincent','Fournier',
  'Morel','Girard','André','Lefebvre','Mercier','Dupont','Lambert','Bonnet','François','Martinez',
  'Legrand','Garnier','Faure','Rousseau','Blanc','Guérin','Muller','Henry','Roussel','Nicolas',
  'Perrin','Morin','Mathieu','Clément','Gauthier','Dumont','Lopez','Fontaine','Chevalier','Robin']) v;

create temp table t_streets (n int primary key, v text) on commit drop;
insert into t_streets
select row_number() over (), v from unnest(array[
  'rue de la République','rue Victor Hugo','avenue Jean Jaurès','rue Pasteur','boulevard Gambetta',
  'rue du Général de Gaulle','place de la Mairie','rue des Lilas','avenue de la Gare','rue Nationale',
  'rue de la Paix','chemin des Vignes','rue Émile Zola','allée des Tilleuls','rue Jean Moulin',
  'avenue Foch','rue des Écoles','boulevard Voltaire','rue du Moulin','impasse des Roses',
  'rue Carnot','quai de la Loire','rue Saint-Michel','avenue des Champs','rue Lamartine']) v;

create temp table t_streets_en (n int primary key, v text) on commit drop;
insert into t_streets_en
select row_number() over (), v from unnest(array[
  'High Street','Station Road','Church Lane','Park Avenue','Main Street','Oak Street','King''s Road','Elm Street']) v;

create temp table t_cities (country text, n int, city text, postal_code text, primary key (country, n)) on commit drop;
insert into t_cities values
  ('France',1,'Paris','75011'),('France',2,'Paris','75015'),('France',3,'Lyon','69003'),('France',4,'Marseille','13006'),
  ('France',5,'Toulouse','31000'),('France',6,'Nice','06000'),('France',7,'Nantes','44000'),('France',8,'Strasbourg','67000'),
  ('France',9,'Montpellier','34000'),('France',10,'Bordeaux','33000'),('France',11,'Lille','59000'),('France',12,'Rennes','35000'),
  ('France',13,'Reims','51100'),('France',14,'Tours','37000'),('France',15,'Grenoble','38000'),('France',16,'Dijon','21000'),
  ('France',17,'Angers','49000'),('France',18,'Annecy','74000'),('France',19,'Brest','29200'),('France',20,'Aix-en-Provence','13100'),
  ('Belgique',1,'Bruxelles','1000'),('Belgique',2,'Liège','4000'),('Belgique',3,'Namur','5000'),
  ('Suisse',1,'Genève','1201'),('Suisse',2,'Lausanne','1003'),('Suisse',3,'Zurich','8001'),
  ('Royaume-Uni',1,'London','SW1A 1AA'),('Royaume-Uni',2,'Manchester','M1 1AE'),('Royaume-Uni',3,'Edinburgh','EH1 1YZ'),
  ('États-Unis',1,'New York','10001'),('États-Unis',2,'Boston','02108'),('États-Unis',3,'San Francisco','94103');

create or replace function pg_temp.fake_address(k text)
returns table (street text, postal_code text, city text, country text) language sql stable as $$
  with c as (
    select case when pg_temp.rnd(k || 'pays', 100) < 85 then 'France'
                when pg_temp.rnd(k || 'pays', 100) < 90 then 'Belgique'
                when pg_temp.rnd(k || 'pays', 100) < 94 then 'Suisse'
                when pg_temp.rnd(k || 'pays', 100) < 97 then 'Royaume-Uni'
                else 'États-Unis' end as country)
  select case when c.country in ('Royaume-Uni', 'États-Unis')
              then (1 + pg_temp.rnd(k || 'num', 250)) || ' ' || (select v from t_streets_en where n = 1 + pg_temp.rnd(k || 'rue', 8))
              else (1 + pg_temp.rnd(k || 'num', 120)) || ' ' || (select v from t_streets where n = 1 + pg_temp.rnd(k || 'rue', 25)) end,
         ci.postal_code, ci.city, c.country
  from c join t_cities ci on ci.country = c.country
   and ci.n = 1 + pg_temp.rnd(k || 'ville', (select count(*)::int from t_cities x where x.country = c.country))
$$;

create or replace function pg_temp.slug(t text) returns text language sql immutable as
$$ select translate(lower(t), 'éèêëàâäîïôöùûüç '' ', 'eeeeaaaiioouuuc') $$;

insert into currencies (currency_code, name, symbol) values
  ('EUR', 'Euro', '€'),
  ('USD', 'Dollar américain', '$'),
  ('GBP', 'Livre sterling', '£'),
  ('CHF', 'Franc suisse', 'CHF'),
  ('CAD', 'Dollar canadien', '$CA');

insert into users (user_id, last_name, first_name, display_name, email, phone, password_hash, created_at, is_active)
select i, ln.v, fn.v,
       case when pg_temp.rnd('pseudo' || i, 3) = 0 then fn.v || left(ln.v, 1) || '.'
            when pg_temp.rnd('pseudo' || i, 3) = 1 then pg_temp.slug(fn.v) || (1970 + pg_temp.rnd('an' || i, 36))
            else fn.v end,
       pg_temp.slug(fn.v) || '.' || pg_temp.slug(ln.v) || i || '@'
         || (array['gmail.com','orange.fr','free.fr','outlook.fr','yahoo.fr','laposte.net'])[1 + pg_temp.rnd('dom' || i, 6)],
       case when pg_temp.rnd('tel' || i, 10) < 8
            then '+33' || (6 + pg_temp.rnd('tel6' || i, 2)) || lpad(pg_temp.rnd('teln' || i, 100000000)::text, 8, '0') end,
       '$2a$10$' || substr(md5('pwd' || i) || md5('sel' || i), 1, 53),

       case when pg_temp.rnd('ins' || i, 10) < 4
            then timestamptz '2023-03-01 10:00+01' + make_interval(days => pg_temp.rnd('j' || i, 300), mins => pg_temp.rnd('m' || i, 600))
            else timestamptz '2024-01-01 10:00+01' + make_interval(days => pg_temp.rnd('j' || i, 1030), mins => pg_temp.rnd('m' || i, 600)) end,
       pg_temp.rnd('actif' || i, 100) >= 8
from generate_series(1, 200) i
join t_first_names fn on fn.n = 1 + pg_temp.rnd('prenom' || i, 50)
join t_last_names  ln on ln.n = 1 + pg_temp.rnd('nom' || i, 50);

insert into addresses (user_id, type, label, street, additional_info, postal_code, city, country)
select u.user_id,
       (array['home','work','other']::address_type[])[k],
       (array['Domicile','Bureau','Chez mes parents'])[k],
       a.street,
       case pg_temp.rnd('cpl' || u.user_id || '-' || k, 6) when 0 then 'Bât. ' || chr(65 + pg_temp.rnd('bat' || u.user_id, 4))
            when 1 then (1 + pg_temp.rnd('et' || u.user_id || k, 6)) || 'e étage' when 2 then 'Digicode ' || (1000 + pg_temp.rnd('dg' || u.user_id || k, 9000)) end,
       a.postal_code, a.city, a.country
from users u
cross join lateral generate_series(1, case when pg_temp.rnd('nbadr' || u.user_id, 20) < 2 then 0
                                           when pg_temp.rnd('nbadr' || u.user_id, 20) < 6 then 1
                                           when pg_temp.rnd('nbadr' || u.user_id, 20) < 16 then 2 else 3 end) k
cross join lateral pg_temp.fake_address(case when k = 1 then 'u' || u.user_id else 'u' || u.user_id || '-' || k end) a
order by u.user_id, k;

insert into categories (category_id, name, parent_category_id) values
  (1, 'Vêtements', null), (2, 'Chaussures', null), (3, 'Accessoires', null), (4, 'Sport & Outdoor', null),
  (5, 'Nouveautés', null), (6, 'Éco-responsable', null), (7, 'Outlet', null),
  (8, 'T-shirts & Polos', 1), (9, 'Chemises', 1), (10, 'Pulls & Sweats', 1), (11, 'Jeans', 1),
  (12, 'Pantalons & Shorts', 1), (13, 'Vestes & Manteaux', 1), (14, 'Enfant', 1),
  (15, 'Sneakers', 2), (16, 'Running', 2), (17, 'Bottes & Boots', 2), (18, 'Sandales & Tongs', 2),
  (19, 'Sacs & Bagagerie', 3), (20, 'Montres', 3), (21, 'Lunettes de soleil', 3),
  (22, 'Casquettes & Bonnets', 3), (23, 'Ceintures & Maroquinerie', 3),
  (24, 'Randonnée', 4), (25, 'Fitness & Training', 4), (26, 'Trail', 4);

insert into brands (brand_id, name) values
  (1, 'Nike'), (2, 'Adidas'), (3, 'Levi''s'), (4, 'Patagonia'), (5, 'Le Coq Sportif'), (6, 'Lacoste'),
  (7, 'Petit Bateau'), (8, 'Veja'), (9, 'Saint James'), (10, 'Aigle'), (11, 'Salomon'), (12, 'The North Face'),
  (13, 'Kickers'), (14, 'Eastpak'), (15, 'Ray-Ban'), (16, 'Lip');

create temp table t_products (product_id int primary key, brand_id int, brand_code text, code text, name text,
  description text, price numeric(10,2), cats int[], colors text[], sizes text[]) on commit drop;
insert into t_products values
  (1, 1,'NK','AM90','Air Max 90','Sneaker iconique avec unité Air visible.',149.99,'{2,15}','{Blanc,Noir}','{40,42,44}'),
  (2, 1,'NK','PEG41','Pegasus 41','Chaussure de running polyvalente et amortie.',139.99,'{2,16,25}','{Bleu,Noir}','{41,43}'),
  (3, 1,'NK','TEE','T-shirt Sportswear Club','T-shirt en coton, coupe classique.',29.99,'{1,8}','{Blanc,Noir,Gris}','{S,M,L}'),
  (4, 1,'NK','HOOD','Sweat à capuche Club Fleece','Molleton doux brossé à l''intérieur.',64.99,'{1,10}','{Gris,Noir}','{M,L}'),
  (5, 1,'NK','HERI','Sac Heritage','Sac bandoulière compact.',34.99,'{3,19}','{Noir}','{NULL}'),
  (6, 2,'AD','SAMBA','Samba OG','Sneaker rétro en cuir avec semelle en gomme.',119.99,'{2,15}','{Blanc,Noir}','{40,42,44}'),
  (7, 2,'AD','STAN','Stan Smith','Le classique du tennis, version cuir recyclé.',109.99,'{2,15,6}','{Blanc,Vert}','{39,41,43}'),
  (8, 2,'AD','TEE','T-shirt Essentials','T-shirt en coton avec logo brodé.',24.99,'{1,8}','{Noir,Blanc}','{S,M,L}'),
  (9, 2,'AD','ULTRA','Ultraboost Light','Running à fort retour d''énergie.',179.99,'{2,16,25}','{Noir,Gris}','{41,43}'),
  (10,2,'AD','CAP','Casquette Trefoil','Casquette ajustable en coton.',22.99,'{3,22}','{Noir,Bleu marine}','{NULL}'),
  (11,3,'LV','501','Jean 501 Original','Le jean coupe droite d''origine.',109.99,'{1,11}','{Indigo,Noir}','{W30L32,W32L32,W34L34}'),
  (12,3,'LV','511','Jean 511 Slim','Jean coupe slim stretch.',99.99,'{1,11,7}','{Indigo,Gris}','{W30L32,W32L32}'),
  (13,3,'LV','TRK','Veste Trucker','Veste en jean classique.',99.99,'{1,13}','{Indigo,Noir}','{M,L}'),
  (14,3,'LV','BELT','Ceinture en cuir','Ceinture en cuir pleine fleur.',39.99,'{3,23}','{Marron,Noir}','{85,95}'),
  (15,4,'PT','NANO','Nano Puff','Doudoune légère, compressible et coupe-vent.',229.99,'{1,13,6}','{Noir,Vert kaki,Bleu marine}','{M,L}'),
  (16,4,'PT','BH40','Black Hole Duffel 40L','Sac de voyage robuste et imperméable.',159.99,'{3,19,24}','{Noir,Orange}','{NULL}'),
  (17,4,'PT','R1','Polaire R1 Air','Polaire technique respirante.',169.99,'{4,24,6}','{Gris,Bleu}','{M,L}'),
  (18,4,'PT','TORR','Veste Torrentshell 3L','Veste de pluie 3 couches.',179.99,'{1,13,24}','{Noir,Rouge}','{S,M,L}'),
  (19,5,'LCS','TEE','T-shirt Essentiels Tricolore','T-shirt en coton avec coq brodé.',34.99,'{1,8}','{Blanc,Bleu marine}','{S,M,L}'),
  (20,5,'LCS','COURT','Baskets Court Classic','Basket de tennis en cuir.',89.99,'{2,15,7}','{Blanc}','{40,42,44}'),
  (21,5,'LCS','SURV','Survêtement Héritage','Survêtement rétro en molleton.',119.99,'{4,25}','{Bleu marine,Bordeaux}','{M,L}'),
  (22,6,'LC','POLO','Polo L.12.12','Le polo original en petit piqué.',109.99,'{1,8}','{Blanc,Bleu marine,Vert}','{S,M,L}'),
  (23,6,'LC','CARNABY','Baskets Carnaby','Basket basse en cuir.',99.99,'{2,15,5}','{Blanc}','{41,43}'),
  (24,6,'LC','PULL','Pull col rond en laine','Pull en laine mérinos.',149.99,'{1,10}','{Gris,Bleu marine}','{M,L}'),
  (25,6,'LC','CAP','Casquette crocodile','Casquette en gabardine de coton.',49.99,'{3,22}','{Noir,Blanc}','{NULL}'),
  (26,7,'PB','MARIN','Marinière enfant','Marinière en coton bio.',29.99,'{1,14}','{Écru}','{4A,6A,8A}'),
  (27,7,'PB','CIRE','Ciré enfant','Ciré imperméable doublé.',69.99,'{1,14,13}','{Jaune,Bleu marine}','{4A,6A,8A}'),
  (28,7,'PB','PYJ','Pyjama en coton','Pyjama doux en côte.',39.99,'{1,14}','{Rose,Bleu}','{4A,6A}'),
  (29,8,'VJ','V10','V-10 Cuir','Basket en cuir tannage végétal.',159.99,'{2,15,6}','{Blanc,Noir}','{38,40,42,44}'),
  (30,8,'VJ','CAMPO','Campo ChromeFree','Basket en cuir sans chrome.',139.99,'{2,15,6}','{Blanc,Beige}','{39,41,43}'),
  (31,8,'VJ','CONDOR','Condor 3 Running','Running biosourcée.',189.99,'{2,16,6}','{Gris,Noir}','{41,43}'),
  (32,9,'SJ','MAT','Marinière Matelot','La marinière bretonne historique.',89.99,'{1,8,6}','{Écru,Bleu marine}','{S,M,L}'),
  (33,9,'SJ','BINIC','Pull marin Binic','Pull marin en laine.',159.99,'{1,10}','{Bleu marine,Écru}','{M,L}'),
  (34,10,'AI','PARC','Bottes Parcours 2','Botte en caoutchouc naturel.',139.99,'{2,17}','{Vert kaki,Noir}','{40,42,44}'),
  (35,10,'AI','CHANT','Bottes de pluie Chanteboot','Botte de pluie légère.',69.99,'{2,17}','{Bleu marine}','{37,39}'),
  (36,10,'AI','RAIN','Veste imperméable Raintech','Veste de pluie respirante.',179.99,'{1,13,24}','{Vert kaki,Bleu marine}','{M,L}'),
  (37,11,'SA','XULTRA','X Ultra 4 GTX','Chaussure de randonnée imperméable.',159.99,'{2,24,4}','{Gris,Noir}','{41,43,45}'),
  (38,11,'SA','SPEED','Speedcross 6','Chaussure de trail à fort grip.',139.99,'{2,16,26}','{Noir,Bleu,Rouge}','{41,43}'),
  (39,11,'SA','ADV12','Sac ADV Skin 12','Sac d''hydratation pour le trail.',129.99,'{3,26,19}','{Noir,Bleu}','{S,M}'),
  (40,11,'SA','GENESIS','S/LAB Genesis','Chaussure de trail longue distance.',189.99,'{2,26}','{Blanc,Jaune}','{42,44}'),
  (41,12,'TNF','NUPT','Doudoune 1996 Retro Nuptse','Doudoune en duvet emblématique.',329.99,'{1,13}','{Noir,Jaune}','{S,M,L}'),
  (42,12,'TNF','BOREA','Sac à dos Borealis','Sac à dos 28 L polyvalent.',99.99,'{3,19,24}','{Noir,Gris}','{NULL}'),
  (43,12,'TNF','BEANIE','Bonnet Salty Dog','Bonnet en maille côtelée.',29.99,'{3,22}','{Noir,Gris,Bordeaux}','{NULL}'),
  (44,12,'TNF','DREW','Sweat Drew Peak','Sweat à capuche en molleton.',79.99,'{1,10,5}','{Noir,Gris}','{M,L,XL}'),
  (45,13,'KK','LEGEND','Kick Legend','La boots iconique en cuir.',109.99,'{2,17,7}','{Marron,Noir}','{40,42}'),
  (46,13,'KK','NEOS','Neosmall enfant','Chaussure enfant à scratch.',59.99,'{2,15}','{Blanc,Rose}','{28,30,32}'),
  (47,14,'EP','PADDED','Sac à dos Padded Pak''r','Le sac à dos culte, garanti 30 ans.',49.99,'{3,19,7}','{Noir,Bleu marine,Gris}','{NULL}'),
  (48,14,'EP','TRANSIT','Valise Transit''R 4 M','Valise souple à roulettes.',149.99,'{3,19}','{Noir}','{NULL}'),
  (49,15,'RB','WAYF','Wayfarer Classic','Lunettes de soleil acétate.',159.99,'{3,21}','{Noir,Marron}','{NULL}'),
  (50,15,'RB','AVIA','Aviator Classic','Lunettes de soleil métal.',169.99,'{3,21}','{Doré,Argenté}','{NULL}'),
  (51,15,'RB','CLUB','Clubmaster','Lunettes de soleil rétro.',179.99,'{3,21}','{Noir}','{NULL}'),
  (52,16,'LIP','HIMA','Montre Himalaya','Montre française au cadran rétro.',199.99,'{3,20,5}','{Noir,Bleu}','{NULL}'),
  (53,16,'LIP','GDG','Montre General de Gaulle','Réédition de la montre de 1938.',349.99,'{3,20}','{Argenté,Doré}','{NULL}'),
  (54,16,'LIP','MACH','Montre Mach 2000','Icône du design des années 70.',289.99,'{3,20}','{Noir,Blanc}','{NULL}'),
  (55,1,'NK','DRIFIT','Short Dri-FIT Challenger','Short de running léger.',39.99,'{4,25,12}','{Noir,Bleu}','{S,M,L}'),
  (56,2,'AD','TIRO','Pantalon Tiro 24','Pantalon d''entraînement.',49.99,'{4,25,12}','{Noir,Bleu marine}','{S,M,L}'),
  (57,3,'LV','CHINO','Chino XX Slim','Chino en sergé stretch.',89.99,'{1,12}','{Beige,Bleu marine}','{W30L32,W32L32,W34L34}'),
  (58,6,'LC','OXF','Chemise Oxford slim','Chemise en coton Oxford.',119.99,'{1,9}','{Blanc,Bleu}','{S,M,L}'),
  (59,9,'SJ','LIN','Chemise en lin','Chemise en lin lavé.',99.99,'{1,9,6}','{Blanc,Beige}','{M,L}'),
  (60,4,'PT','BAGG','Short Baggies 5"','Short polyvalent séchage rapide.',64.99,'{4,12,24}','{Bleu marine,Vert}','{S,M,L}');

create temp table t_colors (color text primary key, code text) on commit drop;
insert into t_colors values ('Blanc','WHT'),('Noir','BLK'),('Gris','GRY'),('Bleu','BLU'),('Bleu marine','NVY'),
  ('Vert','GRN'),('Vert kaki','KHK'),('Rouge','RED'),('Orange','ORG'),('Jaune','YEL'),('Rose','PNK'),('Beige','BEI'),
  ('Marron','BRN'),('Bordeaux','BDX'),('Indigo','IND'),('Écru','ECR'),('Doré','GLD'),('Argenté','SLV');

insert into products (product_id, brand_id, name, description)
select product_id, brand_id, name, description from t_products order by product_id;

insert into product_categories (product_id, category_id)
select p.product_id, c from t_products p cross join unnest(p.cats) c;

insert into product_variants (variant_id, product_id, reference, color, size)
select row_number() over (order by p.product_id, ci, si), p.product_id,
       p.brand_code || '-' || p.code || '-' || tc.code || coalesce('-' || s, ''), c, s
from t_products p
cross join unnest(p.colors) with ordinality as cc(c, ci)
cross join unnest(p.sizes)  with ordinality as ss(s, si)
join t_colors tc on tc.color = cc.c;

insert into price_history (variant_id, currency_code, amount, valid_from, valid_to)
with launch as (
  select product_id, price,
         case when pg_temp.rnd('lance' || product_id, 10) < 7 then timestamptz '2024-01-01 00:00+01'
              else (array[timestamptz '2024-07-01 00:00+02', '2025-03-01 00:00+01', '2025-09-01 00:00+02', '2026-04-01 00:00+02'])
                   [1 + pg_temp.rnd('quand' || product_id, 4)] end as launched_at
  from t_products),
changes as (
  select l.product_id, d as starts_at
  from launch l
  cross join unnest(array[timestamptz '2024-03-01 00:00+01', '2024-09-01 00:00+02', '2025-01-15 00:00+01', '2025-06-01 00:00+02',
                          '2025-10-01 00:00+02', '2026-02-01 00:00+01', '2026-06-15 00:00+02', '2026-09-01 00:00+02']) with ordinality as x(d, m)
  where d > l.launched_at and pg_temp.rnd('chg' || l.product_id || '-' || m, 100) < 40),
periods as (
  select product_id, starts_at,
         lead(starts_at) over w as ends_at,
         row_number() over w - 1 as j,
         count(*) over (partition by product_id) - 1 as k
  from (select product_id, launched_at as starts_at from launch union all select product_id, starts_at from changes) a
  window w as (partition by product_id order by starts_at)),
eur as (
  select p.product_id, p.starts_at, p.ends_at,
         case when p.j = p.k then l.price else round(l.price * (1 - 0.05 * (p.k - p.j))) - 0.01 end as amount
  from periods p join launch l using (product_id)),
rates(currency_code, rate) as (values ('EUR', 1.0), ('USD', 1.12), ('GBP', 0.88), ('CHF', 0.96))
select v.variant_id, r.currency_code,
       case when r.currency_code = 'EUR' then e.amount else round(e.amount * r.rate) - 0.01 end,
       e.starts_at, e.ends_at
from eur e
join product_variants v using (product_id)
cross join rates r
where r.currency_code in ('EUR', 'USD') or pg_temp.rnd('marche' || e.product_id, 10) < 7
order by v.variant_id, r.currency_code, e.starts_at;

insert into promotions (promotion_id, name, discount_percent, scope, valid_from, valid_to, max_uses) values
  (1,  'Bienvenue -10 %',                   10, 'order',    '2024-01-01 00:00+01', '2027-01-01 00:00+01', null),
  (2,  'Black Friday 2024 -20 %',           20, 'order',    '2024-11-29 00:00+01', '2024-12-03 00:00+01', 300),
  (3,  'Black Friday 2025 -20 %',           20, 'order',    '2025-11-28 00:00+01', '2025-12-02 00:00+01', 300),
  (4,  'Programme fidélité -15 %',          15, 'order',    '2024-01-01 00:00+01', '2027-01-01 00:00+01', null),
  (5,  'Soldes d''hiver 2025 chaussures',   25, 'category', '2025-01-08 08:00+01', '2025-02-05 00:00+01', null),
  (6,  'Soldes d''été 2025 vêtements',      20, 'category', '2025-06-25 08:00+02', '2025-07-23 00:00+02', null),
  (7,  'Rentrée sportive 2024 -15 %',       15, 'category', '2024-08-20 00:00+02', '2024-10-01 00:00+02', 500),
  (8,  'Soldes d''hiver 2026 outlet -30 %', 30, 'category', '2026-01-07 08:00+01', '2026-02-04 00:00+01', null),
  (9,  'Montres & lunettes -10 %',          10, 'category', '2026-05-01 00:00+02', '2026-07-01 00:00+02', null),
  (10, 'Fête des pères 2024 -15 %',         15, 'product',  '2024-06-01 00:00+02', '2024-06-17 00:00+02', null),
  (11, 'Semaine Veja -10 %',                10, 'product',  '2025-04-15 00:00+02', '2025-05-01 00:00+02', null),
  (12, 'Patagonia VIP -20 %',               20, 'product',  '2025-10-01 00:00+02', '2026-04-01 00:00+02', 50),
  (13, 'Polos d''été -15 %',                15, 'product',  '2026-06-01 00:00+02', '2026-07-16 00:00+02', null),
  (14, 'Noël 2025 -10 %',                   10, 'order',    '2025-12-01 00:00+01', '2025-12-25 00:00+01', null),
  (15, 'Black Friday 2026 chaussures',      25, 'category', '2026-11-27 00:00+01', '2026-12-01 00:00+01', 1000),
  (16, 'Printemps running -20 %',           20, 'product',  '2026-03-15 00:00+01', '2026-04-16 00:00+02', null);

insert into promotion_categories (promotion_id, category_id) values
  (5, 2), (6, 1), (7, 4), (7, 16), (8, 7), (9, 20), (9, 21), (15, 2);
insert into promotion_products (promotion_id, product_id) values
  (10, 14), (10, 52), (10, 53), (10, 54), (10, 24),
  (11, 29), (11, 30), (11, 31),
  (12, 15), (12, 16), (12, 17), (12, 18), (12, 60),
  (13, 22), (13, 19), (13, 3),
  (16, 2), (16, 9), (16, 31), (16, 38), (16, 55);

insert into promo_codes (code, promotion_id, reserved_user_id, max_uses, one_use_per_customer) values
  ('BIENVENUE10',        1, null, null, true),
  ('BIENVENUE-INSTA',    1, null, 200,  true),
  ('BIENVENUE-ETUDIANT', 1, null, null, true),
  ('BF2024',             2, null, null, true),
  ('BLACKFRIDAY24',      2, null, 150,  false),
  ('BF2025',             3, null, null, true),
  ('CYBER25',            3, null, 150,  false),
  ('SOLDES25',           5, null, null, false),
  ('ETE20',              6, null, null, false),
  ('SPORT15',            7, null, 500,  false),
  ('RUNCLUB15',          7, null, 100,  true),
  ('HIVER30',            8, null, null, false),
  ('ACCESS10',           9, null, null, false),
  ('PAPA15',            10, null, null, true),
  ('VEJA10',            11, null, null, false),
  ('PATA20',            12, null, 40,   true),
  ('POLO15',            13, null, null, false),
  ('NOEL10',            14, null, null, true),
  ('BFSHOES26',         15, null, null, false),
  ('RUN20',             16, null, null, false);

insert into promo_codes (code, promotion_id, reserved_user_id, max_uses, one_use_per_customer)
select 'FIDELITE-' || upper(pg_temp.slug(last_name)) || user_id, 4, user_id, 1, true
from users where user_id in (2, 9, 17, 23, 38, 51, 64, 77, 93, 120) order by user_id;
insert into promo_codes (code, promotion_id, reserved_user_id, max_uses, one_use_per_customer)
select x.prefix || '-' || upper(pg_temp.slug(first_name)) || user_id, x.p, user_id, 3, false
from users cross join (values (6, 'VIP-ETE'), (12, 'VIP-PATA')) x(p, prefix) where user_id in (5, 44) order by user_id, p;

create temp table t_orders on commit drop as
with base as (
  select i,
         (timestamp '2024-01-02 00:00' + make_interval(days => floor(1051 * power((i - 1) / 1500.0, 0.85))::int,
            hours => 8 + pg_temp.rnd('h' || i, 14), mins => pg_temp.rnd('mn' || i, 60))) at time zone 'Europe/Paris' as ordered_at,
         pg_temp.rnd('invite' || i, 100) < 20 as want_guest
  from generate_series(1, 1500) i),
picked as (
  select b.*, u.user_id
  from base b
  left join lateral (
    select e.user_id from users e
    where not b.want_guest and e.created_at < b.ordered_at and exists (select 1 from addresses a where a.user_id = e.user_id)
    order by e.user_id
    offset pg_temp.rnd('client' || b.i, (select greatest(count(*), 1)::int from users e2
                                          where e2.created_at < b.ordered_at and exists (select 1 from addresses a where a.user_id = e2.user_id)))
    limit 1) u on true)
select p.i, p.ordered_at, p.user_id,
       coalesce(u.email, pg_temp.slug(gf.v) || '.' || pg_temp.slug(gl.v) || '.' || g.n || '@'
                || (array['gmail.com','hotmail.fr','orange.fr','icloud.com'])[1 + pg_temp.rnd('gdom' || g.n, 4)]) as email,
       coalesce(u.first_name, gf.v) as first_name,
       coalesce(u.last_name, gl.v)  as last_name,
       case when u.user_id is not null then u.phone
            when pg_temp.rnd('gtel' || g.n, 2) = 0 then '+336' || lpad(pg_temp.rnd('gteln' || g.n, 100000000)::text, 8, '0') end as phone,
       coalesce(ad.street, ga.street) as street,
       case when u.user_id is not null then ad.additional_info end as additional_info,
       coalesce(ad.postal_code, ga.postal_code) as postal_code,
       coalesce(ad.city, ga.city) as city,
       coalesce(ad.country, ga.country) as country
from picked p
left join users u on u.user_id = p.user_id

cross join lateral (select 1 + pg_temp.rnd('qui' || p.i, 220) as n) g
join t_first_names gf on gf.n = 1 + pg_temp.rnd('gprenom' || g.n, 50)
join t_last_names  gl on gl.n = 1 + pg_temp.rnd('gnom' || g.n, 50)
cross join lateral pg_temp.fake_address('invite' || g.n) ga
left join lateral (
  select a.* from addresses a where a.user_id = p.user_id
  order by pg_temp.rnd('adr' || p.i || '-' || a.address_id, 1000), a.address_id limit 1) ad on true;

insert into orders (order_id, public_id, user_id, ordered_at, status, currency_code, total_paid,
  customer_email, customer_first_name, customer_last_name, customer_phone,
  shipping_street, shipping_additional_info, shipping_postal_code, shipping_city, shipping_country)
select i,
       'CMD-' || extract(year from ordered_at at time zone 'Europe/Paris') || '-'
         || lpad((row_number() over (partition by extract(year from ordered_at at time zone 'Europe/Paris') order by ordered_at, i))::text, 6, '0'),
       user_id, ordered_at,

       case when timestamptz '2026-11-18 12:00+01' - ordered_at > interval '30 days'
              then case when pg_temp.rnd('st' || i, 100) < 6 then 'cancelled' else 'delivered' end
            when timestamptz '2026-11-18 12:00+01' - ordered_at > interval '10 days'
              then (array['shipped','delivered','delivered','cancelled'])[1 + pg_temp.rnd('st' || i, 4)]
            when timestamptz '2026-11-18 12:00+01' - ordered_at > interval '4 days'
              then (array['paid','shipped','shipped','cancelled'])[1 + pg_temp.rnd('st' || i, 4)]
            else (array['pending','paid'])[1 + pg_temp.rnd('st' || i, 2)] end::order_status,
       case country when 'Suisse' then 'CHF' when 'Royaume-Uni' then 'GBP' when 'États-Unis' then 'USD' else 'EUR' end,
       0,
       email, first_name, last_name, phone, street, additional_info, postal_code, city, country
from t_orders order by i;

insert into order_items (order_id, variant_id, quantity, unit_price_paid)
select order_id, variant_id,
       case when pg_temp.rnd('qte' || order_id || '-' || variant_id, 10) < 8 then 1
            else 2 + pg_temp.rnd('qte2' || order_id || '-' || variant_id, 2) end,
       amount
from (
  select o.order_id, ph.variant_id, ph.amount,
         row_number() over (partition by o.order_id order by pg_temp.rnd('art' || o.order_id || '-' || ph.variant_id, 1000000), ph.variant_id) as rk,
         case when pg_temp.rnd('nb' || o.order_id, 100) < 40 then 1 when pg_temp.rnd('nb' || o.order_id, 100) < 70 then 2
              when pg_temp.rnd('nb' || o.order_id, 100) < 85 then 3 when pg_temp.rnd('nb' || o.order_id, 100) < 95 then 4 else 5 end as nb
  from orders o
  join price_history ph on ph.currency_code = o.currency_code
   and ph.valid_from <= o.ordered_at and (ph.valid_to is null or ph.valid_to > o.ordered_at)
) x
where rk <= nb
order by order_id, variant_id;

insert into promo_code_usages (promo_code_id, order_id, user_id, customer_email, one_use_per_customer, discount_amount, used_at)
with line_cats as (
  select pc.product_id, pc.category_id from product_categories pc
  union
  select pc.product_id, c.parent_category_id from product_categories pc join categories c using (category_id)
  where c.parent_category_id is not null),
eligible as (
  select o.order_id, pr.promotion_id,
         sum(oi.quantity * oi.unit_price_paid) filter (where
              pr.scope = 'order'
           or (pr.scope = 'product'  and exists (select 1 from promotion_products pp join product_variants v on v.product_id = pp.product_id
                                                 where pp.promotion_id = pr.promotion_id and v.variant_id = oi.variant_id))
           or (pr.scope = 'category' and exists (select 1 from promotion_categories pcat join line_cats lc on lc.category_id = pcat.category_id
                                                 join product_variants v on v.product_id = lc.product_id
                                                 where pcat.promotion_id = pr.promotion_id and v.variant_id = oi.variant_id))) as base
  from orders o
  join order_items oi using (order_id)
  join promotions pr on o.ordered_at >= pr.valid_from and o.ordered_at < pr.valid_to

  where pg_temp.rnd('promo' || o.order_id, 100) < case when pr.valid_to - pr.valid_from > interval '1 year' then 15 else 45 end
  group by o.order_id, pr.promotion_id),
choice as (
  select distinct on (o.order_id) o.order_id, o.user_id, o.customer_email, o.ordered_at, pc.promo_code_id,
         pc.one_use_per_customer, pc.max_uses as code_max, pr.max_uses as promo_max, pr.promotion_id,
         round(e.base * pr.discount_percent / 100, 2) as discount
  from eligible e
  join orders o using (order_id)
  join promotions pr using (promotion_id)
  join promo_codes pc on pc.promotion_id = pr.promotion_id
  where e.base > 0 and (pc.reserved_user_id is null or pc.reserved_user_id = o.user_id)
  order by o.order_id, (pc.reserved_user_id is not null) desc,
           (pr.valid_to - pr.valid_from > interval '1 year'),
           pg_temp.rnd('code' || o.order_id || '-' || pc.promo_code_id, 1000), pc.promo_code_id),
once as (
  select * from (
    select c.*, row_number() over (partition by c.promo_code_id, lower(c.customer_email) order by c.ordered_at, c.order_id) as n_client
    from choice c) x
  where not one_use_per_customer or n_client = 1),
code_cap as (
  select * from (select o.*, row_number() over (partition by promo_code_id order by ordered_at, order_id) as n_code from once o) x
  where code_max is null or n_code <= code_max),
promo_cap as (
  select * from (select c.*, row_number() over (partition by promotion_id order by ordered_at, order_id) as n_promo from code_cap c) x
  where promo_max is null or n_promo <= promo_max)
select promo_code_id, order_id, user_id, customer_email, one_use_per_customer, discount, ordered_at
from promo_cap order by ordered_at, order_id;

update orders o set total_paid = t.subtotal - coalesce(u.discount_amount, 0)
from (select order_id, sum(quantity * unit_price_paid) as subtotal from order_items group by order_id) t
left join promo_code_usages u using (order_id)
where t.order_id = o.order_id;

insert into carts (user_id, created_at, updated_at)
select user_id, c_at,
       case when pg_temp.rnd('maj' || user_id, 2) = 0
            then least(c_at + make_interval(hours => 1 + pg_temp.rnd('majh' || user_id, 48)), timestamptz '2026-11-18 09:00+01') end
from (
  select u.user_id,
         greatest(u.created_at + interval '1 day',
                  timestamptz '2026-11-18 08:00+01' - make_interval(hours => pg_temp.rnd('panier' || u.user_id, 1500))) as c_at
  from users u where u.is_active
  order by pg_temp.rnd('quipanier' || u.user_id, 100000), u.user_id
  limit 120) x
order by c_at, user_id;

insert into cart_items (cart_id, variant_id, quantity)
select cart_id, variant_id, 1 + (pg_temp.rnd('pq' || cart_id || '-' || variant_id, 10) / 8)
from (
  select c.cart_id, v.variant_id,
         row_number() over (partition by c.cart_id order by pg_temp.rnd('pa' || c.cart_id || '-' || v.variant_id, 1000000), v.variant_id) as rk,
         1 + pg_temp.rnd('pnb' || c.cart_id, 5) as nb
  from carts c cross join product_variants v) x
where rk <= nb
order by cart_id, variant_id;

update addresses a set street = (1 + pg_temp.rnd('dem' || a.address_id, 90)) || ' ' || s.v, additional_info = null
from t_streets s
where s.n = 1 + pg_temp.rnd('demrue' || a.address_id, 25) and a.country in ('France', 'Belgique', 'Suisse')
  and pg_temp.rnd('demenage' || a.address_id, 100) < 5;

select setval(pg_get_serial_sequence('users', 'user_id'),               coalesce((select max(user_id) from users), 0) + 1, false);
select setval(pg_get_serial_sequence('addresses', 'address_id'),        coalesce((select max(address_id) from addresses), 0) + 1, false);
select setval(pg_get_serial_sequence('categories', 'category_id'),      coalesce((select max(category_id) from categories), 0) + 1, false);
select setval(pg_get_serial_sequence('brands', 'brand_id'),             coalesce((select max(brand_id) from brands), 0) + 1, false);
select setval(pg_get_serial_sequence('products', 'product_id'),         coalesce((select max(product_id) from products), 0) + 1, false);
select setval(pg_get_serial_sequence('product_variants', 'variant_id'), coalesce((select max(variant_id) from product_variants), 0) + 1, false);
select setval(pg_get_serial_sequence('price_history', 'price_id'),      coalesce((select max(price_id) from price_history), 0) + 1, false);
select setval(pg_get_serial_sequence('carts', 'cart_id'),               coalesce((select max(cart_id) from carts), 0) + 1, false);
select setval(pg_get_serial_sequence('orders', 'order_id'),             coalesce((select max(order_id) from orders), 0) + 1, false);
select setval(pg_get_serial_sequence('promotions', 'promotion_id'),     coalesce((select max(promotion_id) from promotions), 0) + 1, false);
select setval(pg_get_serial_sequence('promo_codes', 'promo_code_id'),   coalesce((select max(promo_code_id) from promo_codes), 0) + 1, false);
select setval(pg_get_serial_sequence('promo_code_usages', 'usage_id'),  coalesce((select max(usage_id) from promo_code_usages), 0) + 1, false);

drop function pg_temp.fake_address(text);
drop function pg_temp.slug(text);
drop function pg_temp.rnd(text, int);

commit;
