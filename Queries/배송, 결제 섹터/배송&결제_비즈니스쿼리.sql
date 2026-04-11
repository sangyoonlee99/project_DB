-- ------------------------------------------
-- Section: [배송 섹터]
-- ------------------------------------------

-- Q14. 2024년 10~12월, 2025년 1~3월 국가별 배송 완료 주문건수 중 상위 3개 국가를 조회하고 비교
-- 목적: 주요 거래국 및 물류 집중도 파악
-- 작성자: 한준
select *
from (
select 
c.country_name AS 국가명,
nvl(q4.배송완료건수, 0) AS "2024_4분기",
nvl(q1.배송완료건수, 0) AS "2025_1분기"
from country c
left join(
select d.country_id, count(*) as 배송완료건수
from delivery d
join delivery_status ds on ds.del_id = d.del_id
where ds.ds_status = '배송완료'
and ds.ds_date between to_date('2024-10-01', 'YYYY-MM-DD')
and to_date('2024-12-31', 'YYYY-MM-DD')
group by d.country_id) q4 on c.country_id = q4.country_id
left join(
select d.country_id, count(*) AS 배송완료건수
from delivery d
join delivery_status ds on ds.del_id = d.del_id
where ds.ds_status = '배송완료'
and ds.ds_date between to_date('2025-01-01', 'YYYY-MM-DD')
and to_date('2025-03-31', 'YYYY-MM-DD')
group by d.country_id) q1 on c.country_id = q1.country_id
order by (nvl(q4.배송완료건수, 0) + nvl(q1.배송완료건수, 0)) desc
)
where rownum <= 3;

-- Q15. 2025년 3~6월 배송완료된 주문 중 주문요청일과 배송완료일의 차이의 평균를 조회
-- 목적: 주문-배송  평균소요일 파악
-- 작성자: 한준
select
round(avg(ds.ds_date - t.order_request_at),2) as 평균_소요일수
from delivery d
join delivery_status ds 
on d.del_id = ds.del_id
join trade t
on d.trade_id = t.trade_id
where ds.ds_status = '배송완료'
and ds.ds_date >= date '2025-03-01'
and ds.ds_date <  date '2025-07-01';

-- Q16. 2025년 3~6월 배송지연된 주문중  배송지연완료일시- 배송지연일시 의 평균조회
-- 목적: 배송지연시 배송완료까지 걸리는 시간의 평균파악> 클레임 관리
-- 작성자: 한준
select 
round(avg(ds_end.ds_date - ds_start.ds_date), 2) as 평균_지연기간
from delivery_status ds_start
join delivery_status ds_end
on ds_start.del_id = ds_end.del_id
where ds_start.ds_status = '배송지연' 
and ds_end.ds_status = '배송지연완료'
and ds_end.ds_date > = date '2025-03-01'
and ds_end.ds_date < date '2025-07-01';

-- Q17. 업체별 2025년 1분기(1~3월) 이내 배송완료된 주문의 주문번호, 배송업체명, 배송완료일을 조회
-- 목적: 배송완료 현황 및 업체별 처리량 파악
-- 작성자: 한준
select
da.agency_name as 배송업체명,
count(d.del_id) as 배송완료건수
from delivery d
join delivery_status ds on d.del_id = ds.del_id
join delivery_agency da on d.agency_id = da.agency_id
where ds.ds_status = '배송완료'
and ds.ds_date >= date '2025-01-01'
and ds.ds_date <  date '2025-04-01'
group by da.agency_name
order by count(d.del_id) desc;


-- ------------------------------------------
-- Section: [결제/환불 섹터]
-- ------------------------------------------

-- Q18. 총 주문 건수 top10인 구매업체 중 환불건이 없는 구매업체의 구매업체명, 주문건수를 조회
-- 목적: 우수 고객 식별
-- 작성자: 현지
select b.buy_name as 구매업체명, 
count(t.trade_id) as 주문건수,
count(r.refund_id) as 환불건수
from 
trade t, refund r, buyer b
where b.buy_id in(
        select buy_id from(
                select b.buy_id, count(t.trade_id) as 업체별주문건수
                from trade t, buyer b
                where b.buy_id = t.buy_id
                group by b.buy_id
                order by 업체별주문건수 desc
        ) where rownum <= 10
) 
and t.trade_id = r.trade_id (+)
and b.buy_id (+) = t.buy_id
group by b.buy_name
having count(r.refund_id) < 1
order by 주문건수 desc;

-- Q19. 2025년 4~6월 월별 환불건수와 상품명, 소분류번호를 조회
-- 목적: 월별 환불 위험 상품군 파악
-- 작성자: 현지
select 
to_char(r.refund_at, 'YYYY-MM') as Month, 
count(r.refund_id) as 환불건수, 
p.proname as 상품명, 
psc.pro_sc_id as 상품소분류번호
from refund r, pro_sc psc, product p, 
prodetail pd, trade t 
where r.trade_id = t.trade_id 
and t.trade_id = pd.trade_id 
and pd.pro_id = p.pro_id 
and psc.pro_sc_id = p.pro_sc_id 
and r.refund_at >= '2025-04-01' 
and r.refund_at < '2025-07-01'
group by to_char(r.refund_at, 'YYYY-MM'), 
p.proname, psc.pro_sc_id
order by to_char(r.refund_at, 'YYYY-MM');

-- Q20. 총 결제금액 대비 총 환불금액 비율(환불율)이 높은 순으로 환불율, 상품중분류, 상품소분류 조회
-- 목적: 고위험 중분류상품군 식별, 품질 검토 목적
-- 작성자: 현지
select
round(sum(nvl(r.refund_amount, 0)) / 
sum(t.total_payment_amount),3) as 환불율,
pbc.pro_bc_type as 상품대분류명,  
pmc.pro_mc_type as 상품중분류명,
psc.pro_sc_type as 상품소분류명
from refund r, trade t, prodetail pd, product p, 
pro_sc psc, pro_mc pmc, pro_bc pbc
where r.trade_id (+) = t.trade_id 
and t.trade_id = pd.trade_id (+) 
and pd.pro_id = p.pro_id (+) 
and psc.pro_sc_id (+) = p.pro_sc_id 
and pmc.pro_mc_id (+) = psc.pro_mc_id 
and pmc.pro_bc_id = pbc.pro_bc_id (+)
group by pmc.pro_mc_type, psc.pro_sc_type, 
pbc.pro_bc_type
having round(sum(nvl(r.refund_amount, 0)) / 
sum(t.total_payment_amount),3) > 0
order by 환불율 desc;

-- Q21. 2025 7~8월에 첫 주문한 신규 구매업체 top5의 이름과 총결제금액, 평균 중개취급수수료를 조회
-- 목적: 최근 유입된 우수 고객, 평균 매출 기여도 파악
-- 작성자: 
select *
from(
select b.buy_name 구매업체명, 
sum(t.total_payment_amount) as 총결제금액, 
round(avg(pd.handling_fee),2) as 평균중개취급수수료
from buyer b, trade t, prodetail pd
where b.buy_id = t.buy_id 
and t.trade_id = pd.trade_id and 
t.order_request_at >= '2025-06-01' 
and t.order_request_at < '2025-09-01'
and not exists(
select t2.buy_id from trade t2 where t2.buy_id = t.buy_id
and t2.order_request_at < '2025-06-01'
)
group by b.buy_name
order by sum(t.total_payment_amount) desc
)
where rownum <= 5;

-- Q22. 총결제금액 top10 구매업체의 환불건수와 환불사유를 조회
-- 목적: 우수 고객의 환불 관리를 통한 이탈 방지
-- 작성자: 현지
select b.buy_name as 구매업체명, 
sum(t.total_payment_amount) as 업체별총결제금액, 
r.refund_reason as 환불사유, 
count(r.refund_id) as 환불건수
from buyer b, refund r, trade t
where b.buy_id in(
select buy_id from(
select b.buy_id, sum(t.total_payment_amount) 
as 업체별총결제금액
from trade t, buyer b
where b.buy_id = t.buy_id
group by b.buy_id
order by 업체별총결제금액 desc
) where rownum <= 10)
and t.trade_id = r.trade_id (+)
and b.buy_id (+) = t.buy_id
group by b.buy_name, r.refund_reason
order by 업체별총결제금액, 환불건수 desc;

-- Q23. 2025 상반기(1~6월) 
국가별·상품중분류별 총결제금액을 내림차순으로 조회
-- 목적: 국가별 선호하는 주력 중분류 상품 파악
-- 작성자: 현지
select 
c.country_name 국가명, 
pmc.pro_mc_type 상품중분류명,
round(sum(
case 
when t.order_request_at >= '2025-01-01' 
and t.order_request_at < '2025-04-01'
then t.total_payment_amount
else 0
end), 0) as "2025 상반기 주문금액"
from 
country c, pro_mc pmc, trade t, pro_sc psc, 
product p, prodetail pd, buyer b
where c.country_id = b.country_id 
and b.buy_id = t.buy_id
and t.trade_id = pd.trade_id
and p.pro_id = pd.pro_id
and p.pro_sc_id = psc.pro_sc_id
and psc.pro_mc_id = pmc.pro_mc_id
group by c.country_name, pmc.pro_mc_type
order by 국가명, "2025 상반기 주문금액" desc;

-- Q24. 국가별 각 결제수단에 대한 총 결제금액 조회
-- 목적: 국가별 거래 유형 파악 및 결제 대금 순환 파악 목적
-- 작성자: 현지
select
pm.method_name "결제수단명", 
c.country_name "국가명", 
round(sum(t.total_payment_amount), 0) "총결제금액"
from 
trade t, payment_method pm, country c, buyer b
where 
pm.method_id = t.method_id
and t.buy_id = b.buy_id
and b.country_id = c.country_id
group by c.country_name, pm.method_name
order by "총결제금액" desc;

-- Q25. 환불사유가 '배송지연'인 배송건의 배송업체 조회
-- 목적: 배송업체 품질 문제 파악 목적
-- 작성자: 현지
select r.refund_reason "환불사유",
da.agency_id "배송업체번호", 
da.agency_name "배송업체명"
from refund r, delivery d, delivery_agency da, trade t
where da.agency_id = d.agency_id
and d.trade_id = t.trade_id
and t.trade_id = r.trade_id
and r.refund_reason like '%배송지연%';

-- Q26. 2025 1분기(1~3월), 2분기(4~6월) 총중개수수료(매출)를 집계하고, 
각 분기별 매출이 높은 순으로 상품중분류명 조회
-- 목적: 분기별 매출 비교, 주력 중분류상품군 파악
-- 작성자: 현지
select
psc.pro_mc_id "상품중분류번호",
round(sum(
case when t.order_request_at >= '2025-01-01' 
and t.order_request_at < '2025-04-01'
then pd.handling_fee
else 0
end), 0) as "1분기 매출액",
round(sum(
case when t.order_request_at >= '2025-04-01' 
and t.order_request_at < '2025-07-01'
then pd.handling_fee 
else 0
end),0) as "2분기 매출액"
from 
trade t, prodetail pd, product p, pro_sc psc
where 
psc.pro_sc_id = p.pro_sc_id
and p.pro_id = pd.pro_id
and pd.trade_id = t.trade_id
group by psc.pro_mc_id
order by "1분기 매출액" desc, "2분기 매출액" desc;