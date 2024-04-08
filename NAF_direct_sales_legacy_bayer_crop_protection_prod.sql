WITH
    MATERIAL_LIST AS (
        SELECT
            *
        FROM (
                 SELECT
                     ROW_NUMBER() OVER (PARTITION BY MATERIAL_NUMBER ORDER BY SOURCE desc, UPDATED.TIME) AS rn,
                         material_number AS MATERIAL_NUMBER,
                     attributes.business_group AS BUSINESS_GROUP_NAME,
                     attributes.line_of_business AS LINE_OF_BUSINESS_NAME,
                     general_data.product_group AS PRODUCT_GROUP_NAME,
                     attributes.brand_name AS PRODUCT_BRAND_NAME,
                     attributes.product_name AS PRODUCT_NAME,
                     attributes.crop_code AS SPECIES_CODE,
                     general_data.division AS DIVISION_NAME
                 FROM
                     bcs-customer360-prod.csw_always_prod.materials_MaterialsV2
                 WHERE
                    (SOURCE = 'BC' or SOURCE = '4S')
                   AND attributes.line_of_business = 'Crop Protection'
                   AND deleted.time IS NULL )
        WHERE
                rn = 1 ),
-- Currency Conversion Rates
    CCR AS (
        SELECT
            DISTINCT from_currency_code,
                     valid_from_date,
                     valid_to_date,
                     exchange_rate
        FROM
            `bcs-customer360-prod.csw.core_exchange_rate_cal`
        WHERE
                to_currency_code = 'EUR'
          AND sap_src_sys_cd = 'x4s'
          AND valid_from_date >= '2020-01-01'
          AND SUBSTR(CAST(valid_from_date AS string),8,10) = '-01'
        ORDER BY
            from_currency_code,
            valid_from_date,
            valid_to_date ),
-- SQ1 (Subquery-1) for Return Quantity
    SQ1 AS (
        SELECT
            'DataOne-Q4S' AS SOURCE_SYSTEM_CODE,
            SUBSTR(DERDATO,5,2) AS CALENDAR_MONTH,
            SUBSTR(DERDATO,1,4) AS CALENDAR_YEAR,
            SHIP_TO__0COUNTRY AS COUNTRY_CODE,
            SALES_GRP AS POSITION_LEVEL_1_CODE,
            SOLD_TO AS OPERATIONAL_ACCOUNT_IDENTIFIER_1,
            'SAP-Q4S-C' AS OPERATIONAL_ACCOUNT_IDENTIFIER_1_SOURCE_SYSTEM_CODE,
            'DISTRIBUTOR' AS OPERATIONAL_ACCOUNT_IDENTIFIER_1_CLASSIFICATION_CODE,
            'D' AS DIRECT_INDIRECT_INDICATOR,
            PARSE_DATE('%Y%m%d',DERDATO) AS FIRST_ORDER_DATE,
            PARSE_DATE('%Y-%m-%d','1900-01-01') AS INVOICE_DATE,
            MATERIAL AS MATERIAL_NUMBER,
            SAFE_CAST(NULL AS STRING) AS LOCAL_CURRENCY_CODE,
            BASE_UOM AS LOCAL_UOM,
            CAST('0.00' AS NUMERIC) AS GROSS_SALES_AMOUNT_LOCAL,
            CAST('0.00' AS NUMERIC) AS NET_SALES_AMOUNT_LOCAL,
            CAST('0.00' AS NUMERIC) AS NET_SALES_QUANTITY_LOCAL,
            CAST('0.00' AS NUMERIC) AS SHIPPED_QUANTITY_LOCAL,
            SUM(DORQTYBU) AS RETURN_QUANTITY_LOCAL,
            CAST('0.00' AS NUMERIC) AS TOTAL_ORDER_QUANTITY_LOCAL
        FROM
            bcs-customer360-prod.h2r_stage.SDO_PIS_UNIQUE
WHERE
    1=1
  AND COMP_CODE IN ('0085',
    '2926')
  AND SALESORG IN ('PC09','EN09','DG09')
  AND DOC_TYPE = 'Z4RT'  --Returns Into Blocked
 -- AND G_CWW007 = '20'
 -- AND DOC_NUMBER__0DOC_CATEG NOT IN ('G',
 --   'B')  -- lack of parameter for NA, can't also find  desc for IBERIA
  AND DERDATO >= '20200101'
GROUP BY
    DERDATO,
    SHIP_TO__0COUNTRY,
    SALES_GRP,
    SOLD_TO,
    MATERIAL,
    BASE_UOM ),
-- SQ2 (Subquery-1) for Total Order Quantity
    SQ2 AS (
SELECT
    'DataOne-Q4S' AS SOURCE_SYSTEM_CODE,
    SUBSTR(DERDATO,5,2) AS CALENDAR_MONTH,
    SUBSTR(DERDATO,1,4) AS CALENDAR_YEAR,
    SHIP_TO__0COUNTRY AS COUNTRY_CODE,
    SALES_GRP AS POSITION_LEVEL_1_CODE,
    SOLD_TO AS OPERATIONAL_ACCOUNT_IDENTIFIER_1,
    'SAP-Q4S-C' AS OPERATIONAL_ACCOUNT_IDENTIFIER_1_SOURCE_SYSTEM_CODE,
    'DISTRIBUTOR' AS OPERATIONAL_ACCOUNT_IDENTIFIER_1_CLASSIFICATION_CODE,
    'D' AS DIRECT_INDIRECT_INDICATOR,
    PARSE_DATE('%Y%m%d',DERDATO) AS FIRST_ORDER_DATE,
    PARSE_DATE('%Y-%m-%d','1900-01-01') AS INVOICE_DATE,
    MATERIAL AS MATERIAL_NUMBER,
    SAFE_CAST(NULL AS STRING) AS LOCAL_CURRENCY_CODE,
    BASE_UOM AS LOCAL_UOM,
    CAST('0.00' AS NUMERIC) AS GROSS_SALES_AMOUNT_LOCAL,
    CAST('0.00' AS NUMERIC) AS NET_SALES_AMOUNT_LOCAL,
    CAST('0.00' AS NUMERIC) AS NET_SALES_QUANTITY_LOCAL,
    CAST('0.00' AS NUMERIC) AS SHIPPED_QUANTITY_LOCAL,
    CAST('0.00' AS NUMERIC) AS RETURN_QUANTITY_LOCAL,
    SUM(DORQTYBU) AS TOTAL_ORDER_QUANTITY_LOCAL
FROM
    bcs-customer360-prod.h2r_stage.SDO_PIS_UNIQUE
WHERE
    1=1
  AND COMP_CODE IN ('0085',
    '2926')
  AND SALESORG IN ('PC09','EN09','DG09')
  AND G_CWW007 = '20'
  AND DOC_NUMBER__0DOC_CATEG NOT IN ('G',
    'B')
  AND DOC_TYPE = 'Z4SD'
  AND DERDATO >= '20200101'
GROUP BY
    DERDATO,
    SHIP_TO__0COUNTRY,
    SALES_GRP,
    SOLD_TO,
    MATERIAL,
    BASE_UOM ),
-- SQ3 (Subquery-3) for Shipped Quantity
    SQ3 AS (
SELECT
    'DataOne-Q4S' AS SOURCE_SYSTEM_CODE,
    SUBSTR(ACT_GI_DTE,5,2) AS CALENDAR_MONTH,
    SUBSTR(ACT_GI_DTE,1,4) AS CALENDAR_YEAR,
    SHIP_TO__0COUNTRY AS COUNTRY_CODE,
    SALES_GRP AS POSITION_LEVEL_1_CODE,
    SOLD_TO AS OPERATIONAL_ACCOUNT_IDENTIFIER_1,
    'SAP-Q4S-C' AS OPERATIONAL_ACCOUNT_IDENTIFIER_1_SOURCE_SYSTEM_CODE,
    'DISTRIBUTOR' AS OPERATIONAL_ACCOUNT_IDENTIFIER_1_CLASSIFICATION_CODE,
    'D' AS DIRECT_INDIRECT_INDICATOR,
    PARSE_DATE('%Y-%m-%d','1900-01-01') AS FIRST_ORDER_DATE,
    PARSE_DATE('%Y-%m-%d','1900-01-01') AS INVOICE_DATE,
    MATERIAL AS MATERIAL_NUMBER,
    SAFE_CAST(NULL AS STRING) AS LOCAL_CURRENCY_CODE,
    BASE_UOM AS LOCAL_UOM,
    CAST('0.00' AS NUMERIC) AS GROSS_SALES_AMOUNT_LOCAL,
    CAST('0.00' AS NUMERIC) AS NET_SALES_AMOUNT_LOCAL,
    CAST('0.00' AS NUMERIC) AS NET_SALES_QUANTITY_LOCAL,
    SUM(ACT_DL_QTY) AS SHIPPED_QUANTITY_LOCAL,
    CAST('0.00' AS NUMERIC) AS RETURN_QUANTITY_LOCAL,
    CAST('0.00' AS NUMERIC) AS TOTAL_ORDER_QUANTITY_LOCAL
FROM
    bcs-customer360-prod.h2r_stage.SDD_PI_UNIQUE
WHERE
    1=1
  AND COMP_CODE IN ('0085',
    '2926')
  AND SALESORG IN ('PC09','EN09','DG09')
  AND ACT_GI_DTE <> '00000000'
  AND ACT_GI_DTE >= '20200101'
GROUP BY
    ACT_GI_DTE,
    SHIP_TO__0COUNTRY,
    SALES_GRP,
    SOLD_TO,
    MATERIAL,
    BASE_UOM ),
-- SQ4 (Subquery-3) for Gross Sales Amount, Net Sales Amount and Net Sales Quantity
    SQ4 AS (
SELECT
    'DataOne-Q4S' AS SOURCE_SYSTEM_CODE,
    SUBSTR(BILL_DATE,5,2) AS CALENDAR_MONTH,
    SUBSTR(BILL_DATE,1,4) AS CALENDAR_YEAR,
    SHIP_TO__0COUNTRY AS COUNTRY_CODE,
    SALES_GRP AS POSITION_LEVEL_1_CODE,
    SOLD_TO AS OPERATIONAL_ACCOUNT_IDENTIFIER_1,
    'SAP-Q4S-C' AS OPERATIONAL_ACCOUNT_IDENTIFIER_1_SOURCE_SYSTEM_CODE,
    'DISTRIBUTOR' AS OPERATIONAL_ACCOUNT_IDENTIFIER_1_CLASSIFICATION_CODE,
    'D' AS DIRECT_INDIRECT_INDICATOR,
    PARSE_DATE('%Y-%m-%d','1900-01-01') AS FIRST_ORDER_DATE,
    PARSE_DATE('%Y-%m-%d','1900-01-01') AS INVOICE_DATE,
    MATERIAL AS MATERIAL_NUMBER,
    DOC_CURRCY AS LOCAL_CURRENCY_CODE,
    BASE_UOM AS LOCAL_UOM,
    cast(SUM(
    CASE
    WHEN BILL_TYPE IN ('YG2W', 'YF2D', 'YRED', 'YL2W') THEN SUBTOTAL_1
    ELSE
    0
    END
    ) as numeric) AS GROSS_SALES_AMOUNT_LOCAL,
    cast(SUM(
    CASE
    WHEN BILL_TYPE IN ('YB3D','YG2W','YF2D','YRED','YL2W','YB4D') THEN NETVAL_INV
    ELSE
    0
    END
    ) as numeric) AS NET_SALES_AMOUNT_LOCAL,
    cast(SUM(
    CASE
    WHEN BILL_TYPE IN ('YB3D','YG2W','YF2D','YRED','YL2W','YB4D') THEN BILL_QTY
    ELSE
    0
    END
    ) as numeric) AS NET_SALES_QUANTITY_LOCAL,
    CAST('0.00' AS NUMERIC)AS SHIPPED_QUANTITY_LOCAL,
    CAST('0.00' AS NUMERIC)AS RETURN_QUANTITY_LOCAL,
    CAST('0.00' AS NUMERIC)AS TOTAL_ORDER_QUANTITY_LOCAL
FROM
    bcs-customer360-prod.h2r_stage.SDB_PI_UNIQUE
WHERE
    1=1
  AND COMP_CODE IN ('0085',
    '2926')
  AND SALESORG IN ('PC09','EN09','DG09')
  AND G_CWW007 = '20'
  AND DISTR_CHAN ='00'
  AND BILL_NUM__0DOC_CATEG <> 'U'
  AND BILL_TYPE IN ('YB3D','YG2W','YF2D','YRED','YL2W','YB4D')
  AND BILL_DATE >= '20200101'
GROUP BY
    BILL_DATE,
    SHIP_TO__0COUNTRY,
    SALES_GRP,
    SOLD_TO,
    MATERIAL,
    DOC_CURRCY,
    BASE_UOM ),
-- MAIN
-- OPL Data Elements
    OPL AS (
SELECT
    COALESCE(GASSP.SOURCE_SYSTEM_CODE,'') AS SOURCE_SYSTEM_CODE,
    COALESCE(GASSP.CALENDAR_YEAR, '1900') AS CALENDAR_YEAR,
    COALESCE(GASSP.CALENDAR_MONTH, '') AS CALENDAR_MONTH,
    COALESCE(GASSP.COUNTRY_CODE, '') AS COUNTRY_CODE,
    COALESCE(GASSP.POSITION_LEVEL_1_CODE, '') AS POSITION_LEVEL_1_CODE,
    COALESCE(GASSP.OPERATIONAL_ACCOUNT_IDENTIFIER_1, '') AS OPL_ACCOUNT_ID,
    COALESCE(GASSP.OPERATIONAL_ACCOUNT_IDENTIFIER_1_SOURCE_SYSTEM_CODE, '') AS OPL_ACCOUNT_SOURCE_SYSTEM_CODE,
    COALESCE(GASSP.OPERATIONAL_ACCOUNT_IDENTIFIER_1_CLASSIFICATION_CODE, '') AS OPL_ACCOUNT_CLASSIFICATION_CODE,
    COALESCE(GASSP.DIRECT_INDIRECT_INDICATOR, '') AS DIRECT_INDIRECT_INDICATOR,
    COALESCE(GASSP.INVOICE_DATE, PARSE_DATE('%Y-%m-%d','1900-01-01')) AS INVOICE_DATE,
    COALESCE(GASSP.MATERIAL_NUMBER, '') AS MATERIAL_NUMBER,
    MAX(FIRST_ORDER_DATE) AS FIRST_ORDER_DATE,
    COALESCE(GASSP.CALENDAR_YEAR, '1900') AS SELLING_SEASON,
    'MY' AS SEASON_CODE,
    'MY ' || SUBSTR(COALESCE(GASSP.CALENDAR_YEAR, '1900'), 3,2 ) AS SEASON_NAME,
    'Crop Science' AS DIVISION_NAME,
    MTRL.BUSINESS_GROUP_NAME AS BUSINESS_GROUP_NAME,
    MTRL.LINE_OF_BUSINESS_NAME AS LINE_OF_BUSINESS,
    MTRL.PRODUCT_GROUP_NAME AS PRODUCT_GROUP,
    MTRL.PRODUCT_BRAND_NAME AS BRAND,
    MTRL.PRODUCT_NAME AS PRODUCT_NAME,
   cast(SUM(GASSP.GROSS_SALES_AMOUNT_LOCAL)as numeric) AS GROSS_SALES_AMOUNT_LOCAL,
   CASE WHEN GASSP.LOCAL_CURRENCY_CODE IS NULL THEN 'EUR'
    ELSE
    GASSP.LOCAL_CURRENCY_CODE 
    END AS GROSS_SALES_AMOUNT_LOCAL_CURRENCY_CODE,
   cast(SUM(CASE GASSP.LOCAL_CURRENCY_CODE WHEN'EUR' THEN GASSP.GROSS_SALES_AMOUNT_LOCAL
    ELSE
    (GASSP.GROSS_SALES_AMOUNT_LOCAL * CCR.exchange_rate)
    END
    ) as numeric) AS GROSS_SALES_AMOUNT_GLOBAL,
    'EUR' AS GROSS_SALES_AMOUNT_GLOBAL_CURRENCY_CODE,
    cast(SUM(GASSP.NET_SALES_AMOUNT_LOCAL) as numeric) AS NET_SALES_AMOUNT_LOCAL,
    CASE WHEN GASSP.LOCAL_CURRENCY_CODE IS NULL THEN 'EUR'
    ELSE
    GASSP.LOCAL_CURRENCY_CODE 
    END AS NET_SALES_AMOUNT_LOCAL_CURRENCY_CODE,
    cast(SUM(CASE GASSP.LOCAL_CURRENCY_CODE WHEN'EUR' THEN GASSP.NET_SALES_AMOUNT_LOCAL
    ELSE
    (GASSP.NET_SALES_AMOUNT_LOCAL * CCR.exchange_rate)
    END
    ) as numeric) AS NET_SALES_AMOUNT_GLOBAL,
    'EUR' AS NET_SALES_AMOUNT_GLOBAL_CURRENCY_CODE,
    cast(SUM(GASSP.NET_SALES_QUANTITY_LOCAL) as numeric) AS NET_SALES_QUANTITY_LOCAL,
    GASSP.LOCAL_UOM AS NET_SALES_QUANTITY_LOCAL_UNIT_OF_MEASURE_CODE,
    cast(NULL as numeric) AS NET_SALES_QUANTITY_GLOBAL,
    cast(NULL as string) AS NET_SALES_QUANTITY_GLOBAL_UNIT_OF_MEASURE_CODE,
    cast(NULL as numeric) AS FORECASTED_SALES_AMOUNT_LOCAL,
    cast(NULL as string) AS FORECASTED_SALES_AMOUNT_LOCAL_CURRENCY_CODE,
    cast(NULL as numeric) AS FORECASTED_SALES_AMOUNT_GLOBAL,
    cast(NULL as string) AS FORECASTED_SALES_AMOUNT_GLOBAL_CURRENCY_CODE,
    cast(NULL as numeric) AS FORECASTED_GROSS_PROFIT_AMOUNT_LOCAL,
    cast(NULL as string) AS FORECASTED_GROSS_PROFIT_AMOUNT_LOCAL_CURRENCY_CODE,
    cast(NULL as numeric) AS FORECASTED_GROSS_PROFIT_AMOUNT_GLOBAL,
    cast(NULL as string) AS FORECASTED_GROSS_PROFIT_AMOUNT_GLOBAL_CURRENCY_CODE,
    cast(SUM(GASSP.TOTAL_ORDER_QUANTITY_LOCAL - GASSP.SHIPPED_QUANTITY_LOCAL) as numeric) AS OPEN_ORDER_QUANTITY_LOCAL,
    GASSP.LOCAL_UOM AS OPEN_ORDER_QUANTITY_LOCAL_UNIT_OF_MEASURE_CODE,
    cast(NULL as numeric)  AS OPEN_ORDER_QUANTITY_GLOBAL,
    NULL AS OPEN_ORDER_QUANTITY_GLOBAL_UNIT_OF_MEASURE_CODE,
    cast(SUM(GASSP.RETURN_QUANTITY_LOCAL) as numeric)  AS RETURN_QUANTITY_LOCAL,
    GASSP.LOCAL_UOM AS RETURN_QUANTITY_LOCAL_UNIT_OF_MEASURE_CODE,
    NULL AS RETURN_QUANTITY_GLOBAL,
    NULL AS RETURN_QUANTITY_GLOBAL_UNIT_OF_MEASURE_CODE,
    SUM(GASSP.SHIPPED_QUANTITY_LOCAL) AS SHIPPED_QUANTITY_LOCAL,
    GASSP.LOCAL_UOM AS SHIPPED_QUANTITY_LOCAL_UNIT_OF_MEASURE_CODE,
     cast(NULL as numeric) AS SHIPPED_QUANTITY_GLOBAL,
    NULL AS SHIPPED_QUANTITY_GLOBAL_UNIT_OF_MEASURE_CODE,
    cast(SUM(GASSP.TOTAL_ORDER_QUANTITY_LOCAL) as numeric) AS TOTAL_ORDER_QUANTITY_LOCAL,
    GASSP.LOCAL_UOM AS TOTAL_ORDER_QUANTITY_LOCAL_UNIT_OF_MEASURE_CODE,
    cast(NULL as numeric) AS TOTAL_ORDER_QUANTITY_GLOBAL,
    NULL AS TOTAL_ORDER_QUANTITY_GLOBAL_UNIT_OF_MEASURE_CODE,
    NULL AS INTERNATIONAL_ARTICLE_NUMBER,
    cast(NULL as numeric) AS NET_PRICE_AMOUNT_LOCAL,
    NULL AS NET_PRICE_AMOUNT_LOCAL_CURRENCY_CODE,
    cast(NULL as numeric) AS NET_PRICE_AMOUNT_GLOBAL,
    NULL AS NET_PRICE_AMOUNT_GLOBAL_CURRENCY_CODE,
    cast(NULL as numeric) AS BUDGET_PRICE_AMOUNT_LOCAL,
    NULL AS BUDGET_PRICE_AMOUNT_LOCAL_CURRENCY_CODE,
    cast(NULL as numeric) AS BUDGET_PRICE_AMOUNT_GLOBAL,
    NULL AS BUDGET_PRICE_AMOUNT_GLOBAL_CURRENCY_CODE
  
FROM (
    SELECT
    *
    FROM
    SQ1
    UNION ALL
    SELECT
    *
    FROM
    SQ2
    UNION ALL
    SELECT
    *
    FROM
    SQ3
    UNION ALL
    SELECT
    *
    FROM
    SQ4 ) GASSP
    INNER JOIN
    MATERIAL_LIST MTRL
ON
    GASSP.MATERIAL_NUMBER = MTRL.MATERIAL_NUMBER
    LEFT JOIN
    CCR AS CCR
    ON
    from_currency_code = GASSP.LOCAL_CURRENCY_CODE
    AND PARSE_DATE('%Y-%m-%d',GASSP.CALENDAR_YEAR || '-'|| GASSP.CALENDAR_MONTH || '-'|| '01') BETWEEN CCR.valid_from_date
    AND CCR.valid_to_date
GROUP BY
    GASSP.SOURCE_SYSTEM_CODE,
    GASSP.CALENDAR_MONTH,
    GASSP.CALENDAR_YEAR,
    GASSP.COUNTRY_CODE,
    GASSP.POSITION_LEVEL_1_CODE,
    GASSP.OPERATIONAL_ACCOUNT_IDENTIFIER_1,
    GASSP.OPERATIONAL_ACCOUNT_IDENTIFIER_1_SOURCE_SYSTEM_CODE,
    GASSP.OPERATIONAL_ACCOUNT_IDENTIFIER_1_CLASSIFICATION_CODE,
    GASSP.DIRECT_INDIRECT_INDICATOR,
    GASSP.INVOICE_DATE,
    CASE WHEN GASSP.LOCAL_CURRENCY_CODE IS NULL THEN 'EUR'
    ELSE
    GASSP.LOCAL_CURRENCY_CODE 
    END,
    GASSP.MATERIAL_NUMBER,
    MTRL.BUSINESS_GROUP_NAME,
    MTRL.LINE_OF_BUSINESS_NAME,
    MTRL.PRODUCT_GROUP_NAME,
    MTRL.PRODUCT_BRAND_NAME,
    MTRL.PRODUCT_NAME,
    GASSP.LOCAL_UOM )
-- CRM Data Enrichment
SELECT DISTINCT
    'C360-DATA-ASSET' AS CRM_ACCOUNT_SOURCE_SYSTEM_CODE,
    CRM.crm_account_id AS CRM_ACCOUNT_ID,
    CRM.crm_account_classification_group_code AS CRM_ACCOUNT_CLASSIFICATION_GROUP_CODE,
    CRM.crm_account_classification_code AS CRM_ACCOUNT_CLASSIFICATION,
    CASE
        WHEN CRM.opl_source_system_code like 'SAP%Q4S%' THEN 'DataOne-Q4S'
            WHEN CRM.opl_source_system_code like 'SAP%QBC%' THEN 'DataOne-QBC'
            ELSE 'DataOne' END as SOURCE_SYSTEM_CODE
,CAST(OPL.CALENDAR_YEAR AS INTEGER) AS CALENDAR_YEAR
,CAST(OPL.CALENDAR_MONTH AS INTEGER) AS CALENDAR_MONTH
,OPL.COUNTRY_CODE
,OPL.POSITION_LEVEL_1_CODE
,OPL.OPL_ACCOUNT_ID
,CRM.opl_source_system_code as OPL_ACCOUNT_SOURCE_SYSTEM_CODE
,OPL.OPL_ACCOUNT_CLASSIFICATION_CODE
,OPL.DIRECT_INDIRECT_INDICATOR
,OPL.INVOICE_DATE
,OPL.MATERIAL_NUMBER
,OPL.FIRST_ORDER_DATE
,CAST(OPL.SELLING_SEASON AS INTEGER) AS SELLING_SEASON
,OPL.SEASON_CODE
,OPL.SEASON_NAME
,OPL.DIVISION_NAME
,OPL.BUSINESS_GROUP_NAME
,OPL.LINE_OF_BUSINESS
,OPL.PRODUCT_GROUP
,OPL.BRAND
,OPL.PRODUCT_NAME
,cast(OPL.GROSS_SALES_AMOUNT_LOCAL as numeric) as GROSS_SALES_AMOUNT_LOCAL
,OPL.GROSS_SALES_AMOUNT_LOCAL_CURRENCY_CODE
,cast(OPL.GROSS_SALES_AMOUNT_GLOBAL as numeric) as GROSS_SALES_AMOUNT_GLOBAL
,OPL.GROSS_SALES_AMOUNT_GLOBAL_CURRENCY_CODE
,cast(OPL.NET_SALES_AMOUNT_LOCAL as numeric) as NET_SALES_AMOUNT_LOCAL
,OPL.NET_SALES_AMOUNT_LOCAL_CURRENCY_CODE
,cast(OPL.NET_SALES_AMOUNT_GLOBAL as numeric) as NET_SALES_AMOUNT_GLOBAL
,OPL.NET_SALES_AMOUNT_GLOBAL_CURRENCY_CODE
,cast(OPL.NET_SALES_QUANTITY_LOCAL as numeric) as NET_SALES_QUANTITY_LOCAL
,OPL.NET_SALES_QUANTITY_LOCAL_UNIT_OF_MEASURE_CODE
,cast(OPL.NET_SALES_QUANTITY_GLOBAL as numeric) as NET_SALES_QUANTITY_GLOBAL
,CAST(OPL.NET_SALES_QUANTITY_GLOBAL_UNIT_OF_MEASURE_CODE AS STRING) AS NET_SALES_QUANTITY_GLOBAL_UNIT_OF_MEASURE_CODE
,cast(OPL.FORECASTED_SALES_AMOUNT_LOCAL as numeric) as FORECASTED_SALES_AMOUNT_LOCAL
,CAST(OPL.FORECASTED_SALES_AMOUNT_LOCAL_CURRENCY_CODE AS STRING) AS FORECASTED_SALES_AMOUNT_LOCAL_CURRENCY_CODE
,cast(OPL.FORECASTED_SALES_AMOUNT_GLOBAL as numeric) AS FORECASTED_SALES_AMOUNT_GLOBAL
,CAST(OPL.FORECASTED_SALES_AMOUNT_GLOBAL_CURRENCY_CODE AS STRING) AS FORECASTED_SALES_AMOUNT_GLOBAL_CURRENCY_CODE
,cast(OPL.FORECASTED_GROSS_PROFIT_AMOUNT_LOCAL as numeric) AS FORECASTED_GROSS_PROFIT_AMOUNT_LOCAL
,CAST(OPL.FORECASTED_GROSS_PROFIT_AMOUNT_LOCAL_CURRENCY_CODE AS STRING) AS FORECASTED_GROSS_PROFIT_AMOUNT_LOCAL_CURRENCY_CODE
,cast(OPL.FORECASTED_GROSS_PROFIT_AMOUNT_GLOBAL as numeric) AS FORECASTED_GROSS_PROFIT_AMOUNT_GLOBAL
,CAST(OPL.FORECASTED_GROSS_PROFIT_AMOUNT_GLOBAL_CURRENCY_CODE AS STRING) AS FORECASTED_GROSS_PROFIT_AMOUNT_GLOBAL_CURRENCY_CODE
,cast(OPL.OPEN_ORDER_QUANTITY_LOCAL as numeric) AS OPEN_ORDER_QUANTITY_LOCAL
,OPL.OPEN_ORDER_QUANTITY_LOCAL_UNIT_OF_MEASURE_CODE
,cast(OPL.OPEN_ORDER_QUANTITY_GLOBAL as numeric) AS OPEN_ORDER_QUANTITY_GLOBAL
,CAST(OPL.OPEN_ORDER_QUANTITY_GLOBAL_UNIT_OF_MEASURE_CODE AS STRING) AS OPEN_ORDER_QUANTITY_GLOBAL_UNIT_OF_MEASURE_CODE
,cast(OPL.RETURN_QUANTITY_LOCAL as numeric) AS RETURN_QUANTITY_LOCAL 
,OPL.RETURN_QUANTITY_LOCAL_UNIT_OF_MEASURE_CODE
,cast(OPL.RETURN_QUANTITY_GLOBAL as numeric) AS RETURN_QUANTITY_GLOBAL
,CAST(OPL.RETURN_QUANTITY_GLOBAL_UNIT_OF_MEASURE_CODE AS STRING) AS RETURN_QUANTITY_GLOBAL_UNIT_OF_MEASURE_CODE
,cast(OPL.SHIPPED_QUANTITY_LOCAL as numeric) AS SHIPPED_QUANTITY_LOCAL
,OPL.SHIPPED_QUANTITY_LOCAL_UNIT_OF_MEASURE_CODE
,CAST(OPL.SHIPPED_QUANTITY_GLOBAL AS NUMERIC) AS SHIPPED_QUANTITY_GLOBAL
,CAST(OPL.SHIPPED_QUANTITY_GLOBAL_UNIT_OF_MEASURE_CODE AS STRING) AS SHIPPED_QUANTITY_GLOBAL_UNIT_OF_MEASURE_CODE
,cast(OPL.TOTAL_ORDER_QUANTITY_LOCAL as numeric) AS TOTAL_ORDER_QUANTITY_LOCAL
,OPL.TOTAL_ORDER_QUANTITY_LOCAL_UNIT_OF_MEASURE_CODE
,cast(OPL.TOTAL_ORDER_QUANTITY_GLOBAL as numeric) AS TOTAL_ORDER_QUANTITY_GLOBAL
,CAST(OPL.TOTAL_ORDER_QUANTITY_GLOBAL_UNIT_OF_MEASURE_CODE AS STRING) AS TOTAL_ORDER_QUANTITY_GLOBAL_UNIT_OF_MEASURE_CODE
,cast(OPL.INTERNATIONAL_ARTICLE_NUMBER as INTEGER) AS INTERNATIONAL_ARTICLE_NUMBER
,cast(OPL.NET_PRICE_AMOUNT_LOCAL as numeric) AS NET_PRICE_AMOUNT_LOCAL
,CAST(OPL.NET_PRICE_AMOUNT_LOCAL_CURRENCY_CODE AS STRING) AS NET_PRICE_AMOUNT_LOCAL_CURRENCY_CODE
,cast(OPL.NET_PRICE_AMOUNT_GLOBAL as numeric) AS NET_PRICE_AMOUNT_GLOBAL
,CAST(OPL.NET_PRICE_AMOUNT_GLOBAL_CURRENCY_CODE AS STRING) AS NET_PRICE_AMOUNT_GLOBAL_CURRENCY_CODE
,cast(OPL.BUDGET_PRICE_AMOUNT_LOCAL as numeric) AS BUDGET_PRICE_AMOUNT_LOCAL
,CAST(OPL.BUDGET_PRICE_AMOUNT_LOCAL_CURRENCY_CODE AS STRING) AS BUDGET_PRICE_AMOUNT_LOCAL_CURRENCY_CODE
,cast(OPL.BUDGET_PRICE_AMOUNT_GLOBAL as numeric) AS BUDGET_PRICE_AMOUNT_GLOBAL
,CAST(OPL.BUDGET_PRICE_AMOUNT_GLOBAL_CURRENCY_CODE AS STRING) AS BUDGET_PRICE_AMOUNT_GLOBAL_CURRENCY_CODE
, 'A' AS action_type
, CURRENT_TIMESTAMP AS row_insert_timestamp
, CURRENT_TIMESTAMP AS row_update_timestamp
FROM
    OPL OPL
        JOIN
    `bcs-customer360-prod.staging_eu.crm_opl_xref` CRM
    ON
                TRIM(OPL.OPL_ACCOUNT_ID) = TRIM(CRM.opl_account_id)
            AND TRIM(OPL.OPL_ACCOUNT_CLASSIFICATION_CODE) = TRIM(CRM.opl_account_classification_code)
