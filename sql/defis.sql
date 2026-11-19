-- Défi 01 - Montant moyen d'une commande validée par chaque pays de livraison ; comparer aussi le nombre de commandes et le chiffre d'affaires
with taux(currency_code, eur) as (
  values ('EUR', 1.00), ('USD', 0.86), ('GBP', 1.15), ('CHF', 1.07)
)
select o.shipping_country                              as pays,
       count(*)                                        as nb_commandes,
       round(sum(o.total_paid * t.eur), 2)             as ca_eur,
       round(avg(o.total_paid * t.eur), 2)             as panier_moyen_eur,
       round(100 * sum(o.total_paid * t.eur) / sum(sum(o.total_paid * t.eur)) over (), 1) as part_ca_pct
from orders o
join taux t on t.currency_code = o.currency_code
where o.status in ('paid', 'shipped', 'delivered')
group by o.shipping_country
order by panier_moyen_eur desc;

-- Défi 02 - Quelles sont les 20 villes au panier moyen le plus élevé, parmi celles ayant au moins 30 commandes ?
with taux(currency_code, eur) as (
  values ('EUR', 1.00), ('USD', 0.86), ('GBP', 1.15), ('CHF', 1.07)
)
select o.shipping_city                   as ville,
       o.shipping_country                as pays,
       count(*)                          as nb_commandes,
       round(avg(o.total_paid * t.eur), 2) as panier_moyen_eur
from orders o
join taux t on t.currency_code = o.currency_code
where o.status in ('paid', 'shipped', 'delivered')
group by o.shipping_city, o.shipping_country
having count(*) >= 30
order by panier_moyen_eur desc
limit 20;

-- Défi 03 - Quels sont les 50 clients avec le plus de commandes payées sur 12 mois ? Afficher aussi leur dépense totale
with taux(currency_code, eur) as (
  values ('EUR', 1.00), ('USD', 0.86), ('GBP', 1.15), ('CHF', 1.07)
)
select lower(o.customer_email)                     as client_email,
       max(o.customer_first_name || ' ' || o.customer_last_name) as client,
       bool_or(o.user_id is not null)              as a_un_compte,
       count(*)                                    as nb_commandes,
       round(sum(o.total_paid * t.eur), 2)         as depense_totale_eur
from orders o
join taux t on t.currency_code = o.currency_code
where o.status in ('paid', 'shipped', 'delivered')
  and o.ordered_at >= now() - interval '12 months'
group by lower(o.customer_email)
order by nb_commandes desc, depense_totale_eur desc
limit 50;

-- Défi 04 - Quelles variantes actives du catalogue n'ont jamais été achetées ?
select v.variant_id,
       v.reference,
       p.name  as produit,
       b.name  as marque,
       v.color as couleur,
       v.size  as taille
from product_variants v
join products p on p.product_id = v.product_id
join brands b   on b.brand_id = p.brand_id
where exists (
        select 1 from price_history ph
        where ph.variant_id = v.variant_id
          and ph.valid_from <= now()
          and (ph.valid_to is null or ph.valid_to > now())
      )
  and not exists (
        select 1
        from order_items oi
        join orders o on o.order_id = oi.order_id
        where oi.variant_id = v.variant_id
          and o.status in ('paid', 'shipped', 'delivered')
      )
order by b.name, p.name, v.reference;

-- Défi 05 - Classez les marques par chiffre d'affaires en tenant compte des quantités et des prix réellement payés
with taux(currency_code, eur) as (
  values ('EUR', 1.00), ('USD', 0.86), ('GBP', 1.15), ('CHF', 1.07)
),
lignes as (
  select o.order_id,
         oi.variant_id,
         oi.quantity,
         oi.quantity * oi.unit_price_paid
           * o.total_paid / nullif(sum(oi.quantity * oi.unit_price_paid) over (partition by o.order_id), 0)
           * t.eur as ca_net_eur
  from orders o
  join order_items oi on oi.order_id = o.order_id
  join taux t on t.currency_code = o.currency_code
  where o.status in ('paid', 'shipped', 'delivered')
)
select rank() over (order by sum(l.ca_net_eur) desc) as rang,
       b.name                                      as marque,
       sum(l.quantity)                             as quantite_vendue,
       count(distinct l.order_id)                  as nb_commandes,
       round(sum(l.ca_net_eur), 2)                 as ca_eur
from lignes l
join product_variants v on v.variant_id = l.variant_id
join products p         on p.product_id = v.product_id
join brands b           on b.brand_id = p.brand_id
group by b.name
order by rang;

-- Défi 07 - Quels clients ayant déjà acheté n'ont rien commandé depuis 180 jours ?
select lower(o.customer_email)                     as client_email,
       max(o.customer_first_name || ' ' || o.customer_last_name) as client,
       bool_or(o.user_id is not null)              as a_un_compte,
       count(*)                                    as nb_commandes,
       max(o.ordered_at)                           as derniere_commande,
       current_date - max(o.ordered_at)::date      as jours_sans_commande
from orders o
where o.status in ('paid', 'shipped', 'delivered')
group by lower(o.customer_email)
having max(o.ordered_at) < now() - interval '180 days'
order by derniere_commande desc;

-- Défi 08 - Quelle catégorie réalise le plus de ventes dans chaque pays ? (un produit peut appartenir à plusieurs catégories)
with taux(currency_code, eur) as (
  values ('EUR', 1.00), ('USD', 0.86), ('GBP', 1.15), ('CHF', 1.07)
),
lignes as (
  select o.order_id,
         o.shipping_country,
         oi.variant_id,
         oi.quantity,
         oi.quantity * oi.unit_price_paid
           * o.total_paid / nullif(sum(oi.quantity * oi.unit_price_paid) over (partition by o.order_id), 0)
           * t.eur as ca_net_eur
  from orders o
  join order_items oi on oi.order_id = o.order_id
  join taux t on t.currency_code = o.currency_code
  where o.status in ('paid', 'shipped', 'delivered')
),
ventes as (
  select l.shipping_country,
         c.name                     as categorie,
         sum(l.quantity)            as quantite_vendue,
         sum(l.ca_net_eur)          as ca_eur
  from lignes l
  join product_variants v    on v.variant_id = l.variant_id
  join product_categories pc on pc.product_id = v.product_id
  join categories c          on c.category_id = pc.category_id
  group by l.shipping_country, c.category_id, c.name
),
classement as (
  select v.*, rank() over (partition by shipping_country order by ca_eur desc) as rang
  from ventes v
)
select shipping_country     as pays,
       categorie,
       quantite_vendue,
       round(ca_eur, 2)     as ca_eur
from classement
where rang = 1
order by ca_eur desc;

-- Défi 18 - Quelle est la variation en euros et en pourcentage du CA par pays par rapport au mois précédent, y compris les mois à zéro ?
with taux(currency_code, eur) as (
  values ('EUR', 1.00), ('USD', 0.86), ('GBP', 1.15), ('CHF', 1.07)
),
validees as (
  select o.shipping_country, date_trunc('month', o.ordered_at) as mois, o.total_paid * t.eur as ca_eur
  from orders o
  join taux t on t.currency_code = o.currency_code
  where o.status in ('paid', 'shipped', 'delivered')
),
mois as (
  select generate_series(min(mois), max(mois), interval '1 month') as mois from validees
),
pays as (
  select distinct shipping_country from validees
),
ca_mensuel as (
  select p.shipping_country, m.mois, coalesce(sum(v.ca_eur), 0) as ca_eur
  from pays p
  cross join mois m
  left join validees v on v.shipping_country = p.shipping_country and v.mois = m.mois
  group by p.shipping_country, m.mois
),
avec_precedent as (
  select shipping_country, mois, ca_eur,
         lag(ca_eur) over (partition by shipping_country order by mois) as ca_mois_precedent
  from ca_mensuel
)
select shipping_country                                  as pays,
       to_char(mois, 'YYYY-MM')                          as mois,
       round(ca_eur, 2)                                  as ca_eur,
       round(ca_mois_precedent, 2)                       as ca_mois_precedent_eur,
       round(ca_eur - ca_mois_precedent, 2)              as variation_eur,
       round(100 * (ca_eur - ca_mois_precedent) / nullif(ca_mois_precedent, 0), 1) as variation_pct
from avec_precedent
order by pays, mois;

-- Défi 19 - Quelle proportion des clients repasse commande dans les 30, 60 et 90 jours après leur premier achat ?
with achats as (
  select lower(customer_email) as client, ordered_at
  from orders
  where status in ('paid', 'shipped', 'delivered')
),
premiers as (
  select client, min(ordered_at) as premier_achat
  from achats
  group by client
),
retours as (
  select p.client,
         p.premier_achat,
         min(a.ordered_at) - p.premier_achat as delai_retour
  from premiers p
  left join achats a on a.client = p.client and a.ordered_at > p.premier_achat
  group by p.client, p.premier_achat
)
select d.jours                                                       as delai_jours,
       count(*) filter (where r.premier_achat <= now() - d.jours * interval '1 day') as clients_observables,
       count(*) filter (where r.premier_achat <= now() - d.jours * interval '1 day'
                          and r.delai_retour <= d.jours * interval '1 day')          as clients_revenus,
       round(100.0 * count(*) filter (where r.premier_achat <= now() - d.jours * interval '1 day'
                                        and r.delai_retour <= d.jours * interval '1 day')
             / nullif(count(*) filter (where r.premier_achat <= now() - d.jours * interval '1 day'), 0), 1) as proportion_pct
from retours r
cross join (values (30), (60), (90)) as d(jours)
group by d.jours
order by d.jours;

-- Défi 20 - Quelles paires de variantes sont les plus fréquentes dans une même commande ? Comptez chaque paire une fois par commande
select a.variant_id                  as variante_a,
       va.reference                  as reference_a,
       b.variant_id                  as variante_b,
       vb.reference                  as reference_b,
       count(distinct a.order_id)    as nb_commandes
from order_items a
join order_items b       on b.order_id = a.order_id and a.variant_id < b.variant_id
join orders o            on o.order_id = a.order_id
join product_variants va on va.variant_id = a.variant_id
join product_variants vb on vb.variant_id = b.variant_id
where o.status in ('paid', 'shipped', 'delivered')
group by a.variant_id, va.reference, b.variant_id, vb.reference
order by nb_commandes desc, variante_a, variante_b
limit 20;
