-- ------------------------------------------
-- Section: [사원/조직/회사 섹터]
-- ------------------------------------------

-- Q1. 각 담당 사원이 관리 중인 상품 품목수 집계 조회
-- 목적: 담당 사원별 업무량 분석
-- 작성자: 한준
select 
s.sa_id, s.saname, s.saemail, 
count(p.pro_id) as product_sawon_cnt
from sawon s
left join 
product p
on s.sa_id = p.sa_id
group by s.sa_id,s.saname,s.saemail
order by product_sawon_cnt desc;


-- ------------------------------------------
-- Section: [구매/판매업체 섹터]
-- ------------------------------------------

-- Q2. 구매자가 등록한 희망구매품목에서 실제로 구매한 희망구매품목 비율
-- 목적: 위시 to 구매 전환비율 확인
-- 작성자: 상윤
with buy_sc as 
(
        select p.pro_sc_id,p.proname 
                ,sc.pro_sc_type,b.buy_name,b.buy_id
        from product p 
                ,pro_sc sc 
                ,buyer b
                ,trade t,prodetail dt
        where p.pro_sc_id = sc.pro_sc_id
        and b.buy_id = t.buy_id
        and t.trade_id = dt.trade_id
        and p.pro_id = dt.pro_id
),
wish_sc as 
(
        select sc.pro_sc_id,b.buy_name 
                ,sc.pro_sc_type,b.buy_id
        from pro_sc sc,buyer b,target_product tg 
        where b.buy_id = tg.buy_id 
        and sc.pro_sc_id = tg.pro_sc_id
)
select round
(
        (
        select count(distinct w.buy_name||b.pro_sc_type)
        from buy_sc b,wish_sc w
        where w.pro_sc_id = b.pro_sc_id
        and w.buy_id = b.buy_id
        ) / 
        (select count(pro_sc_id) from target_product)
,2)*100"위시 to 구매 전환비율(%)"  
from dual;

-- Q3. 구매자 정보가 가장 많이 등록된 국가
-- 목적: 가장 주문이 활발한 국가 파악
-- 작성자: 한준
select country_id, buyer_count
from (
select country_id, count(*) as buyer_count
from buyer
group by country_id
) sub
where buyer_count = (
select max(buyer_count)
from(
select count(*) as buyer_count
from buyer
group by country_id
));

-- Q4. 희망구매건수가 15개 이상인 상품소분류명을 조회, 내림차순 정렬
-- 목적: 구매업체 수요가 많은 품목 조회
-- 작성자: 현지
select 
pbc.pro_bc_type as 상품대분류명, 
pmc.pro_mc_type as 상품중분류명, 
psc.pro_sc_type as 상품소분류명,
count(tp.target_id) as 희망구매건수
from pro_bc pbc, pro_mc pmc, pro_sc psc, 
target_product tp, buyer b
where b.buy_id = tp.buy_id 
and tp.pro_sc_id = psc.pro_sc_id
and psc.pro_mc_id = pmc.pro_mc_id 
and pbc.pro_bc_id = pmc.pro_bc_id
group by pbc.pro_bc_type, pmc.pro_mc_type, 
psc.pro_sc_type
having count(tp.target_id) >= 15
order by 희망구매건수 desc;


-- ------------------------------------------
-- Section: [상품/재고/카테고리 섹터]
-- ------------------------------------------

-- Q5. 등록 후 3개월 이상 경과한 주문이 없는 상품의 비율을 소분류별로 조회
-- 목적: 악성 재고 파악
-- 작성자: 호성
select 
sc.pro_sc_type as 소분류명,
count(case when p.pro_id not in (select pro_id from prodetail) 
then 1 end) as 주문없는상품수,
count(*) as 전체상품수,
to_char(round(count(case when p.pro_id not in (select pro_id from prodetail) then 1 end) / count(*) * 100,2),
'fm999,990.00' ) || '%' as 주문없는상품
from product p
join pro_sc sc on p.pro_sc_id = sc.pro_sc_id
where p.pro_reg_at <= add_months(sysdate, -3)
group by sc.pro_sc_type
order by 주문없는상품 desc;

-- Q6. 2025년 4~6월 동안 판매된 소분류별 총 매출 금액(재고*수량_소계)이 높은순으로 조회
-- 목적: 지난분기의 실적 및 소분류별 판매동향 파악 목적
-- 작성자: 호성
select 
sc.pro_sc_type as 소분류명,
to_char(sum(pd.prodetail_amount * p.saleprice), 'fm$999,999,999,990.00') as 총매출금액
from prodetail pd
join trade t on pd.trade_id = t.trade_id
join product p on pd.pro_id = p.pro_id
join pro_sc sc on p.pro_sc_id = sc.pro_sc_id
where t.order_request_at between to_date('2025-04-01', 'yyyy-mm-dd') and to_date('2025-06-30', 'yyyy-mm-dd')
group by sc.pro_sc_type
order by 총매출금액 desc;

-- Q7. 2025년 1~6월 중 대분류(여성) 중분류(아우터) 소분류(자켓)의 상품 매출 금액 조회
-- 목적: 특성 상품의 판매 매출 조회
-- 작성자: 호성
select 
bc.pro_bc_type as 대분류,
mc.pro_mc_type as 중분류,
sc.pro_sc_type as 소분류,
to_char(sum(pd.subtotal_price), 'fm$999,999,999,990.00') as 총매출금액
from prodetail pd
join trade t on pd.trade_id = t.trade_id
join product p on pd.pro_id = p.pro_id
join pro_sc sc on p.pro_sc_id = sc.pro_sc_id
join pro_mc mc on sc.pro_mc_id = mc.pro_mc_id
join pro_bc bc on mc.pro_bc_id = bc.pro_bc_id
where t.order_request_at 
between to_date('2025-01-01', 'yyyy-mm-dd')
and to_date('2025-06-30', 'yyyy-mm-dd')
and bc.pro_bc_type = '여자'
and mc.pro_mc_type = '아우터'
and sc.pro_sc_type = '자켓'
group by bc.pro_bc_type, mc.pro_mc_type, sc.pro_sc_type;

-- Q8. 2025년 1~6월 소분류(셔츠,티셔츠,긴바지,반바지,자켓,코트)별 매출 금액 및 수량 조회
-- 목적: 1년간의 매출 및 수량 조회 후 매출 목표 수립
-- 작성자: 호성
select 
sc.pro_sc_type as 소분류명,
to_char(sum(pd.subtotal_price), 'fm$999,999,999,990.00') as 총매출금액,
to_char(sum(pd.prodetail_amount), 'fm999,999,999,990') as 총판매수량
from prodetail pd
join trade t on pd.trade_id = t.trade_id
join product p on pd.pro_id = p.pro_id
join pro_sc sc on p.pro_sc_id = sc.pro_sc_id
where t.order_request_at between to_date('2025-01-01', 'yyyy-mm-dd') and to_date('2025-06-30', 'yyyy-mm-dd')
and sc.pro_sc_type IN ('셔츠', '티셔츠', '긴바지', '반바지', '자켓', '코트')
group by sc.pro_sc_type
order by 총매출금액 desc;

-- Q9. 2025년 1~3월 대분류(남성,여성,키즈)의 국가별 매출 금액 및 수량 조회
-- 목적: 상반기 정산용 매출 조회
-- 작성자: 호성
select 
bc.pro_bc_type as 대분류,
c.country_name as 국가명,
to_char(sum(pd.subtotal_price), 'fm$999,999,999,990.00') as 총매출금액,
to_char(sum(pd.prodetail_amount), 'fm999,999,999,990') as 총판매수량
from prodetail pd
join trade t on pd.trade_id = t.trade_id
join buyer b on t.buy_id = b.buy_id
join country c on b.country_id = c.country_id
join product p on pd.pro_id = p.pro_id
join pro_sc sc on p.pro_sc_id = sc.pro_sc_id
join pro_mc mc on sc.pro_mc_id = mc.pro_mc_id
join pro_bc bc on mc.pro_bc_id = bc.pro_bc_id
where t.order_request_at 
between to_date('2025-01-01', 'yyyy-mm-dd') and to_date('2025-03-31', 'yyyy-mm-dd')
and bc.pro_bc_type in ('남자', '여자', '키즈')
group by bc.pro_bc_type, c.country_name
order by bc.pro_bc_type, 총매출금액 desc;

-- Q10. 2025년 1~6월 소분류별 환불 금액 조회
-- 목적: 환불금액 정리로 업체 정리 및 클레임 정리 목적
-- 작성자: 호성
select 
sc.pro_sc_type as 소분류명,
to_char(sum(r.refund_amount), 'fm$999,999,999,990.00') as 환불금액합계
from refund r
join trade t on r.trade_id = t.trade_id
join prodetail pd on t.trade_id = pd.trade_id
join product p on pd.pro_id = p.pro_id
join pro_sc sc on p.pro_sc_id = sc.pro_sc_id
where r.refund_at between to_date('2025-01-01', 'yyyy-mm-dd') and to_date('2025-06-30', 'yyyy-mm-dd')
group by sc.pro_sc_type
order by 환불금액합계 desc;

-- Q11. 2025년 1~6월 판매자별 판매 금액 및 정산금액 조회
-- 목적: 판매자별 매입 및 정산 금액 확인 목적
-- 작성자: 호성
select 
s.sell_id,
s.sellname AS 판매자명,
to_char(nvl(sum(distinct pd_sales.총판매금액), 0), 'fm$999,999,999,990.00') as 총판매금액,
to_char(nvl(sum(distinct st_sales.총정산금액), 0), 'fm$999,999,999,990.00') AS 총정산금액
from seller s
left join (select p.sell_id,
sum(pd.subtotal_price) as 총판매금액
from prodetail pd
join trade t on pd.trade_id = t.trade_id
join product p on pd.pro_id = p.pro_id
where t.order_request_at between to_date('2025-01-01','yyyy-mm-dd') and to_date('2025-06-30','yyyy-mm-dd')
group by p.sell_id
) pd_sales on s.sell_id = pd_sales.sell_id
left join (select sell_id,
sum(set_amount) as 총정산금액
from settlement
where set_date between to_date('2025-01-01','yyyy-mm-dd') and to_date('2025-06-30','yyyy-mm-dd')
group by sell_id
) st_sales on s.sell_id = st_sales.sell_id
group by s.sell_id, s.sellname
order by 총판매금액 desc;

-- Q12. 2025년 6월 판매 금액이 $5000 이하인 상품소분류 조회
-- 목적: 경비 절감 및 비인기 제품 파악 목적
-- 작성자: 호성
select 
sc.pro_sc_type AS 소분류명,
to_char(sum(pd.subtotal_price), 'fm$999,999,999,990.00') as 총판매금액
from prodetail pd
join trade t on pd.trade_id = t.trade_id
join product p on pd.pro_id = p.pro_id
join pro_sc sc on p.pro_sc_id = sc.pro_sc_id
where t.order_request_at between to_date('2025-06-01', 'yyyy-mm-dd') and to_date('2025-06-30', 'yyyy-mm-dd')
group by sc.pro_sc_type
having sum(pd.subtotal_price) <= 5000
order by 총판매금액;

-- Q13. 2025년 1~6월 국가별 소분류(자켓, 코트) 상품 구매금액 조회
-- 목적: 국가별 소분류 상품의 니즈 파악(계절에 맞는 상품 파악 목적)
-- 작성자: 호성
select 
c.country_name as 국가명,
sc.pro_sc_type as 소분류명,
to_char(sum(pd.subtotal_price), 'fm$999,999,999,990.00') as 총구매금액
from prodetail pd
join trade t on pd.trade_id = t.trade_id
join buyer b on t.buy_id = b.buy_id
join country c on b.country_id = c.country_id
join product p on pd.pro_id = p.pro_id
join pro_sc sc on p.pro_sc_id = sc.pro_sc_id
where t.order_request_at between to_date('2025-01-01', 'yyyy-mm-dd') and to_date('2025-06-30', 'yyyy-mm-dd')
and sc.pro_sc_type IN ('자켓', '코트')
group by c.country_name, sc.pro_sc_type
order by sc.pro_sc_type, SUM(pd.subtotal_price) desc;
