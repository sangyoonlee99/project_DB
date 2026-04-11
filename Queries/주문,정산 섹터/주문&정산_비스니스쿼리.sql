-- ------------------------------------------
-- Section: [주문 / 거래 ]
-- ------------------------------------------

-- Q27. 소분류 내 상품주문량이 (24년11월-25년2월)과 비교하여 (25년3월-25년6월)에 50% 이상 증가한 소분류항목 조회
-- 목적: 트랜드인기제품파악
-- 작성자: 상윤
select 
        sc.pro_sc_type"소분류"
        ,nvl(sum(feb.주문건수),0)"24년11월-25년2월주문"
        ,nvl(sum(june.주문건수),0)"25년3월-25년6월주문"
        ,round(
                (nvl(sum(june.주문건수),0)-nvl(sum(feb.주문건수),0))
                /nvl(sum(feb.주문건수),0)
        ,2)*100 "증가율(%)"
from 
        product p,
        (select p.pro_id , count(dt.prodetail_id) as 주문건수 
                from product p, prodetail dt,trade t 
                where p.pro_id(+) = dt.pro_id 
                and t.trade_id(+) = dt.trade_id 
                and t.order_request_at 
                between TO_DATE('2024-11-01','yyyy-mm-dd')
                and TO_DATE('2025-02-28','yyyy-mm-dd')
                group by p.pro_id) feb,
        (select p.pro_id , count(dt.prodetail_id) as 주문건수
                from product p, prodetail dt,trade t 
                where p.pro_id(+) = dt.pro_id 
                and t.trade_id(+) = dt.trade_id 
                and t.order_request_at 
                between TO_DATE('2025-03-01','yyyy-mm-dd')
                and TO_DATE('2025-06-30','yyyy-mm-dd')
                group by p.pro_id) june,
        pro_sc sc 
where p.pro_id = feb.pro_id(+) 
        and p.pro_id = june.pro_id(+) 
        and p.pro_sc_id(+) = sc.pro_sc_id 
group by sc.pro_sc_type
having sum(feb.주문건수)*1.5<=sum(june.주문건수);

-- Q28. 2024/11/15까지 주문이 안된 상품이 그 이후로 팔린 날짜 확인
-- 목적: 비활성 상품의 활성화 시점 파악
-- 작성자: 상윤
SELECT p.pro_id,p.proname,MIN(t.order_request_at)
FROM product p, prodetail dt, trade t 
WHERE p.pro_id = dt.pro_id 
AND t.trade_id = dt.trade_id 
AND p.pro_reg_at 
<= TO_DATE('20241115','YYYYMMDD') 
AND p.pro_id 
NOT IN 
        (
        SELECT dt1.pro_id
        FROM prodetail dt1,trade t1,product p1
        WHERE dt1.trade_id = t1.trade_id
        AND p1.pro_id = dt1.pro_id
        AND TRUNC(t1.order_request_at) 
        <= TO_DATE('20241115','YYYYMMDD')
        )
GROUP BY p.pro_id,p.proname 
HAVING MIN(t.order_request_at)
>= TO_DATE('20241116','YYYYMMDD');

-- Q29. 2025년 8월 신용장거래 대비 계좌 거래 비율
-- 목적: 결제 수단 선호도 조사
-- 작성자: 상윤
SELECT
	ROUND
	(
		(
		SELECT COUNT(a.prodetail_id)
		FROM account a, prodetail dt, trade t
		WHERE dt.prodetail_id = a.prodetail_id
		AND t.trade_id = dt.trade_id
		AND t.order_request_at 
		BETWEEN TO_DATE('20250801','YYYYMMDD')
		AND TO_DATE('20250831','YYYYMMDD')
		) /
		(
    SELECT COUNT(l.prodetail_id)
    FROM lc l, prodetail dt, trade t
    WHERE dt.prodetail_id = l.prodetail_id
    AND t.trade_id = dt.trade_id
    AND t.order_request_at 
    BETWEEN TO_DATE('20250801','YYYYMMDD') 
    AND TO_DATE('20250831','YYYYMMDD')
    )
  ,2
  ) "8월신용장대비계좌비율"
FROM dual;

-- Q30. 1~3월 사이 누적금액 10000달러 이상 업체 추출
-- 목적: 결제대금 상위 업체 파악
-- 작성자: 상윤
select
        sum(dt.subtotal_price)"누적금액($)"
        ,s.sellname"업체명" from prodetail dt
        ,seller s
        ,trade t
where s.sell_id = dt.sell_id 
        and t.trade_id = dt.trade_id 
        and order_request_at 
        between to_date('20250101','yyyymmdd')
        and to_date('20250331','yyyymmdd')
group by s.sellname
having sum(dt.subtotal_price) >= 10000
order by "누적금액($)" desc;

-- Q31. 주문상세 수량 합계가 1,500개 이상인 판매자
-- 목적: 대형거래자 파악
-- 작성자: 상윤
select * 
 from 
	 (
	 select 
		 b.buy_name"구매업체명"
		 ,sum(dt.prodetail_amount)"주문수량합계"
	 from prodetail dt,trade t,buyer b
	 where t.trade_id = dt.trade_id
	 and b.buy_id = t.buy_id
	 group by b.buy_name
	 )
 where 주문수량합계 >= 1500
 order by 주문수량합계 desc;

-- Q32. 첫 주문 후 30일 이내 다시 주문한 구매자 목록
-- 목적: 구매자 재이용률(리텐션) 분석
-- 작성자: 상윤
with firstorder as
(
	select b_f.buy_name
		,b_f.buy_id
		,min(t_f.order_request_at)"첫주문일" 
	from buyer b_f,trade t_f 
	where b_f.buy_id = t_f.buy_id 
	group by b_f.buy_id,b_f.buy_name
),
secondorder as
(
	select b1.buy_name
		,b1.buy_id
		,min(t1.order_request_at)"두번째주문일" 
	from buyer b1,trade t1 
	where b1.buy_id = t1.buy_id 
	and
		t1.order_request_at >
		(
			select 
				min(t1_s.order_request_at)"첫주문일forsub"
			from trade t1_s 
			where t1.buy_id = t1_s.buy_id
		) 
	group by b1.buy_name,b1.buy_id
)
select a.buy_name, b.첫주문일,c.두번째주문일 
from buyer a,firstorder b,secondorder c
where a.buy_id = b.buy_id
and a.buy_id = c.buy_id
and (두번째주문일 - 첫주문일)<=30;

-- Q33. 2025년 1월~6월까지 판매자별 주문상세건수 탑10 판매자 조회
-- 목적: 판매자별로 판매활동량 파악
-- 작성자: 상윤
select *
from 
(
	select s.sell_id
		,s.sellname
		,count(dt.prodetail_id) as "주문건수"
	from seller s,prodetail dt,trade t
	where s.sell_id = dt.sell_id
	and t.trade_id = dt.trade_id
	and t.order_request_at 
	between to_date('20250101','yyyymmdd')
	and to_date('20250630','yyyymmdd')
	group by s.sell_id,s.sellname
	order by "주문건수" desc
)
where rownum <= 10 ;

-- Q34. 24년 10월부터 25년 8월까지 달별 거래총액
-- 목적: 플랫폼 전체 매출 추이 / 성장률 분석
-- 작성자: 상윤
select to_char(t.order_request_at,'yyyy-mm')"월"
	,round(sum(dt.subtotal_price),0)"거래총액($)"
from prodetail dt,trade t
where t.trade_id = dt.trade_id
group by to_char(t.order_request_at,'yyyy-mm')
order by "월" asc;

-- Q35. 국가별로 많이 주문된 중분류 top 1 추출
-- 목적: 국가별 선호 분류 파악
-- 작성자: 상윤
select *
from 
	(
	select c.country_name"나라이름"
		,mc.pro_mc_type"중분류 타입"
		,count(mc.pro_mc_type)"중분류주문건수"
		,rank() over
			(
			partition by c.country_name 
			order by count(mc.pro_mc_type) desc
			)"등수" 
	from pro_mc mc,pro_sc sc,product p
		,prodetail dt,trade t,buyer b,country c
	where mc.pro_mc_id = sc.pro_mc_id 
	and sc.pro_sc_id = p.pro_sc_id 
	and p.pro_id = dt.pro_id 
	and t.trade_id = dt.trade_id 
	and b.buy_id = t.buy_id 
	and c.country_id = b.country_id
	and t.order_request_at 
	between to_date('20250101','yyyymmdd')
	and to_date('20250630','yyyymmdd')
	group by c.country_name , mc.pro_mc_type
	)
where 등수 = 1
order by "나라이름";


-- ------------------------------------------
-- Section: [정산]
-- ------------------------------------------

-- Q36. 정산금액 대비 배송비 부담율
-- 목적: 배송비 부담 비율 확인으로 비용 절감 및 효율성 개선 목적
-- 작성자: 한준
select
v.trade_id as 주문번호,
v.sell_id as 판매자번호,
v.settlement_amount as 정산금액,
round(
(nvl(d.totalcost, 0) / nvl(p2.seller_count, 1)) / v.settlement_amount * 100,2) as 배송비_부담율
from settlement_view v
join (
select 
p1.trade_id,
count(distinct p1.sell_id) as seller_count
from prodetail p1
group by p1.trade_id) p2 
on v.trade_id = p2.trade_id
left join delivery d on v.trade_id = d.trade_id
order by v.trade_id, v.sell_id;

-- Q37. 2025년 동안 주문 후 정산까지 걸린 평균시간
-- 목적: 주문부터 정산 완료까지 프로세스 속도 모니터링 및 개선 목적
-- 작성자: 한준
select 
round(avg(ds.ds_date - t.order_request_at),2) as 평균총소요일
from trade t
join delivery d
on d.trade_id = t.trade_id
join delivery_status ds
on d.del_id = ds.del_id
where ds.ds_status = '배송완료'
and ds.ds_date between to_date('2025-01-01', 'yyyy-mm-dd')
and to_date('2025-08-24', 'yyyy-mm-dd');

-- Q38. 2025년 판매자별 평균 정산금액
-- 목적: 판매자별 수익성 평가 및 정산 상태 모니터링 목적
-- 작성자: 한준
select
round(avg(평균정산금액),2) as "2025평균정산금액"
from(
select
v.trade_id,
v.sell_id,
round(avg(v.settlement_amount),2) as 평균정산금액
from settlement_view v
join settlement s
on s.sell_id = v.sell_id
where s.set_date between to_date('2025-01-01', 'yyyy-mm-dd')
and to_date('2025-08-24', 'yyyy-mm-dd')
group by v.trade_id, v.sell_id);

-- Q39. 2024년 10월~12월과 2025년 1월~3월의 총정산금액을 비교하시오.
-- 목적: 기간별(분기별) 정산 조회하여 정산 실적의 변화 및 성장을 파악하기 위함.
-- 작성자: 한준
select 
sum(case 
when s.set_date between to_date('2024-10-01', 'yyyy-mm-dd')
and to_date('2024-12-31', 'yyyy-mm-dd')
then v.settlement_amount
else 0
end) as "2024_4분기_총정산금액",
sum(case
when s.set_date between to_date('2025-01-01', 'yyyy-mm-dd')
and to_date('2025-03-31', 'yyyy-mm-dd')
then v.settlement_amount
else 0
end) as "2025_1분기_총정산금액",
round(
sum(case
when s.set_date between to_date('2024-10-01', 'yyyy-mm-dd')
and to_date('2025-12-31', 'yyyy-mm-dd')
then v.settlement_amount
else 0
end)
-
sum(case
when s.set_date between to_date('2025-01-01', 'yyyy-mm-dd')
and to_date('2025-03-31', 'yyyy-mm-dd')
then v.settlement_amount
else 0
end) ,2) as"증감금액"
from settlement_view v
join settlement s
on s.sell_id = v.sell_id
where s.set_date between to_date('2024-10-01', 'YYYY-MM-DD')
and to_date('2025-03-31', 'YYYY-MM-DD');

-- Q40. 주문마다 각판매자별로 얼마를 정산해줘야 하는지 정산금액을 계산하기
-- 목적: 주문에 다수 판매자 가 있는 경우가 존재하여 , 판매자 개별 각각 정산금액 조회 및 관리 하기 위함

총결제금액을 판매자별 매출 비율대로 나누고, 거기서 수수료와 배송비를 뺀값이 정산금액
-- 작성자: 한준
select
t.trade_id,
s.sell_id,
round(
(t.total_payment_amount * (p2.seller_total_price / p2.total_trade_price))
- (nvl(p2.handling_fee, 0) + (nvl(d.totalcost, 0) / nvl(p2.seller_count, 1))), 2) as 정산금액
from trade t
join (
select 
p1.trade_id,
p1.sell_id,
p1.seller_total_price,
p1.handling_fee,
count(*) over (partition by p1.trade_id) as seller_count,      
sum(p1.seller_total_price) over (partition by p1.trade_id) as total_trade_price
from (
select 
p.trade_id,
p.sell_id,
sum(p.ask_price * p.prodetail_amount) as seller_total_price,
sum(p.handling_fee) as handling_fee
from prodetail p
group by p.trade_id, p.sell_id
) p1) p2 on t.trade_id = p2.trade_id
join seller s 
on p2.sell_id = s.sell_id
left join delivery d 
on t.trade_id = d.trade_id
order by t.trade_id asc;

-- Q. 정산금액뷰 설정
-- 목적: 뷰 사용해서 편하게 정산금액 조회
create or replace view settlement_view as
select
t.trade_id,
s.sell_id,
round(
(t.total_payment_amount * (p2.seller_total_price / p2.total_trade_price))
- (nvl(p2.handling_fee, 0) + (nvl(d.totalcost, 0) / nvl(p2.seller_count, 1))), 2) as settlement_amount   
from trade t
join (
select 
p1.trade_id,
p1.sell_id,
p1.seller_total_price,
p1.handling_fee,
count(*) over (partition by p1.trade_id) as seller_count,
sum(p1.seller_total_price) over (partition by p1.trade_id) as total_trade_price
from (
select 
p.trade_id,
p.sell_id,
sum(p.ask_price * p.prodetail_amount) as seller_total_price,
sum(p.handling_fee) as handling_fee
from prodetail p
group by p.trade_id, p.sell_id
) p1 ) p2 on t.trade_id = p2.trade_id
join seller s on p2.sell_id = s.sell_id
left join delivery d on t.trade_id = d.trade_id;
