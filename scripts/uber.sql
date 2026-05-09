CREATE
OR
REPLACE
    ALGORITHM = MERGE VIEW vwCen_ConciliacionAgregador_UBER AS

WITH
    params AS (
        SELECT DATE_FORMAT(CURDATE(), '%Y-%m-01') - INTERVAL 2 MONTH AS cutoff
    ),
    uber_params AS (
        SELECT 13.92 AS fee_amt, 0.75 AS tol_fee, 800.00 AS max_diff
    ),
    cta_banco AS (
        SELECT
            CodigoCuenta AS CuentaBanco,
            Nombre AS NombreBanco
        FROM Centura_CatContable
        WHERE
            Clave = 'BANCO_bbva326'
            AND Activo = 1
    ),
    cta_uber AS (
        SELECT
            CodigoCuenta AS CuentaAgregador,
            Nombre AS NombreAgregador
        FROM Centura_CatContable
        WHERE
            UPPER(TRIM(Clave)) = 'UBER'
            AND Activo = 1
    ),

/* =========================================================
BANCO
========================================================= */

ban_src AS (
    SELECT v.Id, v.Fecha, v.Total, v.CLASIFICACION
    FROM
        vwCen_BanAgregador v
        JOIN params p ON v.Fecha >= p.cutoff
    WHERE
        v.Total <> 0
),
ban_uber AS (
    SELECT
        b.Id AS BancoId,
        b.Fecha AS FechaPago,
        ROUND(b.Total, 2) AS ImporteBanco
    FROM ban_src b
    WHERE
        b.CLASIFICACION = 'UBER'
),

/* =========================================================
ESPERADO
========================================================= */

exp_uber_detalle AS (
    SELECT DATE(c.Fecha) AS FechaOper, c.Sucursal, c.PagoSucursal
    FROM
        Centura_Agregadores c
        JOIN params p ON c.Fecha >= (p.cutoff - INTERVAL 30 DAY)
    WHERE
        c.Plataforma = 'UBER'
),
exp_uber_base AS (
    SELECT
        e.Sucursal,
        e.PagoSucursal,
        e.FechaOper,
        WEEKDAY(e.FechaOper) AS DiaSemana,
        CASE
            WHEN WEEKDAY(e.FechaOper) IN (5, 6) THEN DATE_SUB(
                e.FechaOper,
                INTERVAL(WEEKDAY(e.FechaOper) -4) DAY
            )
            ELSE e.FechaOper
        END AS FechaBase,
        CASE
            WHEN WEEKDAY(e.FechaOper) IN (0, 1, 2, 3) THEN DATE_ADD(e.FechaOper, INTERVAL 1 DAY)
            WHEN WEEKDAY(e.FechaOper) = 4 THEN DATE_ADD(e.FechaOper, INTERVAL 3 DAY)
            WHEN WEEKDAY(e.FechaOper) = 5 THEN DATE_ADD(e.FechaOper, INTERVAL 2 DAY)
            ELSE DATE_ADD(e.FechaOper, INTERVAL 1 DAY)
        END AS PagoAnchor
    FROM exp_uber_detalle e
),

/* =========================================================
OPTIMIZADO:
ELIMINADO SUBQUERY CORRELACIONADO MIN()
========================================================= */

exp_uber_sum AS (
    SELECT
        MIN(d2.Fecha) AS FechaPago,
        b.Sucursal,
        ROUND(SUM(b.PagoSucursal), 2) AS ImporteEsperado,
        b.FechaBase
    FROM
        exp_uber_base b
        JOIN Tesoreria_Date d2 ON d2.Fecha >= b.PagoAnchor
        AND d2.DiaHabil = 1
    GROUP BY
        b.Sucursal,
        b.FechaBase
),
exp_uber_norm AS (
    SELECT
        e.FechaPago,
        COALESCE(
            s1.Sucursal,
            su.Sucursal,
            e.Sucursal
        ) AS Sucursal,
        COALESCE(s1.IdSuc, su.IdSuc) AS IdSuc,
        COALESCE(s1.Segmento, su.Segmento) AS Segmento,
        CASE
            WHEN COALESCE(s1.IdSuc, su.IdSuc) IS NULL THEN 'SIN_MAPEO'
            ELSE 'CAT_UBER'
        END AS FuenteMapeo,
        CONCAT(
            'UBER|',
            DATE_FORMAT(e.FechaPago, '%Y-%m-%d'),
            '|',
            COALESCE(
                s1.Sucursal,
                su.Sucursal,
                e.Sucursal
            ),
            '|',
            DATE_FORMAT(e.FechaBase, '%Y-%m-%d')
        ) AS Rastreo,
        e.ImporteEsperado
    FROM
        exp_uber_sum e
        LEFT JOIN Centura_Sucursal s1 ON s1.Sucursal = e.Sucursal
        AND s1.Estatus = '1'
        LEFT JOIN Centura_Sucursal su ON su.Uber = e.Sucursal
        AND su.Estatus = '1'
),
exp_uber_pos AS (
    SELECT *
    FROM exp_uber_norm
    WHERE
        ImporteEsperado > 0
),
exp_uber_neg AS (
    SELECT *
    FROM exp_uber_norm
    WHERE
        ImporteEsperado <= 0
),

/* =========================================================
MATCH EXACT
========================================================= */

ban_exact AS (
    SELECT b.BancoId, b.FechaPago, b.ImporteBanco, ROW_NUMBER() OVER (
            PARTITION BY
                b.FechaPago, b.ImporteBanco
            ORDER BY b.BancoId
        ) AS rn_amt
    FROM ban_uber b
),
exp_exact AS (
    SELECT e.FechaPago, e.Sucursal, e.IdSuc, e.Segmento, e.FuenteMapeo, e.Rastreo, e.ImporteEsperado, ROW_NUMBER() OVER (
            PARTITION BY
                e.FechaPago, e.ImporteEsperado
            ORDER BY e.Rastreo
        ) AS rn_amt
    FROM exp_uber_pos e
),
match_uber_exact AS (
    SELECT
        e.FechaPago,
        'UBER' AS Agregador,
        e.Sucursal,
        e.IdSuc,
        e.Segmento,
        e.FuenteMapeo,
        e.Rastreo,
        CAST(b.BancoId AS CHAR) AS BancoIds,
        'UBER exact match' AS Observacion,
        b.ImporteBanco AS ImporteBancoSuc,
        e.ImporteEsperado AS ImporteEsperadoSuc,
        b.BancoId AS BancoIdNum
    FROM
        exp_exact e
        JOIN ban_exact b ON b.FechaPago = e.FechaPago
        AND b.rn_amt = e.rn_amt
        AND b.ImporteBanco = e.ImporteEsperado
),
matched_banco_1 AS (
    SELECT FechaPago, BancoIdNum AS BancoId
    FROM match_uber_exact
    GROUP BY
        FechaPago,
        BancoIdNum
),
matched_esp_1 AS (
    SELECT FechaPago, Rastreo
    FROM match_uber_exact
    GROUP BY
        FechaPago,
        Rastreo
),
ban_rest_1 AS (
    SELECT b.BancoId, b.FechaPago, b.ImporteBanco
    FROM
        ban_uber b
        LEFT JOIN matched_banco_1 mb ON mb.FechaPago = b.FechaPago
        AND mb.BancoId = b.BancoId
    WHERE
        mb.BancoId IS NULL
),
exp_rest_1 AS (
    SELECT e.FechaPago, e.Sucursal, e.IdSuc, e.Segmento, e.FuenteMapeo, e.Rastreo, e.ImporteEsperado
    FROM
        exp_uber_pos e
        LEFT JOIN matched_esp_1 me ON me.FechaPago = e.FechaPago
        AND me.Rastreo = e.Rastreo
    WHERE
        me.Rastreo IS NULL
),

/* =========================================================
MATCH FEE
========================================================= */

uber_fee_candidates AS (
    SELECT
        b.FechaPago,
        b.BancoId,
        b.ImporteBanco,
        e.Rastreo,
        e.Sucursal,
        e.IdSuc,
        e.Segmento,
        e.FuenteMapeo,
        e.ImporteEsperado,
        ABS(
            ABS(
                e.ImporteEsperado - b.ImporteBanco
            ) - p.fee_amt
        ) AS FeeDiff,
        ROW_NUMBER() OVER (
            PARTITION BY
                b.FechaPago,
                b.BancoId
            ORDER BY ABS(
                    ABS(
                        e.ImporteEsperado - b.ImporteBanco
                    ) - p.fee_amt
                ), ABS(
                    e.ImporteEsperado - b.ImporteBanco
                )
        ) AS rn_banco,
        ROW_NUMBER() OVER (
            PARTITION BY
                b.FechaPago,
                e.Rastreo
            ORDER BY ABS(
                    ABS(
                        e.ImporteEsperado - b.ImporteBanco
                    ) - p.fee_amt
                ), ABS(
                    e.ImporteEsperado - b.ImporteBanco
                )
        ) AS rn_esp
    FROM
        ban_rest_1 b
        JOIN exp_rest_1 e ON e.FechaPago = b.FechaPago
        AND ABS(
            ABS(
                e.ImporteEsperado - b.ImporteBanco
            ) - p.fee_amt
        ) <= p.tol_fee
        CROSS JOIN uber_params p
),
match_uber_fee AS (
    SELECT
        c.FechaPago,
        'UBER' AS Agregador,
        c.Sucursal,
        c.IdSuc,
        c.Segmento,
        c.FuenteMapeo,
        c.Rastreo,
        CAST(c.BancoId AS CHAR) AS BancoIds,
        'UBER fee match' AS Observacion,
        c.ImporteBanco AS ImporteBancoSuc,
        c.ImporteEsperado AS ImporteEsperadoSuc,
        c.BancoId AS BancoIdNum
    FROM uber_fee_candidates c
    WHERE
        c.rn_banco = 1
        AND c.rn_esp = 1
),
matched_banco_2 AS (
    SELECT FechaPago, BancoId
    FROM matched_banco_1
    UNION ALL
    SELECT FechaPago, BancoIdNum
    FROM match_uber_fee
),
matched_esp_2 AS (
    SELECT FechaPago, Rastreo
    FROM matched_esp_1
    UNION ALL
    SELECT FechaPago, Rastreo
    FROM match_uber_fee
),
matched_banco_2_distinct AS (
    SELECT FechaPago, BancoId
    FROM matched_banco_2
    GROUP BY
        FechaPago,
        BancoId
),
matched_esp_2_distinct AS (
    SELECT FechaPago, Rastreo
    FROM matched_esp_2
    GROUP BY
        FechaPago,
        Rastreo
),
ban_rest_2 AS (
    SELECT b.BancoId, b.FechaPago, b.ImporteBanco
    FROM
        ban_uber b
        LEFT JOIN matched_banco_2_distinct mb ON mb.FechaPago = b.FechaPago
        AND mb.BancoId = b.BancoId
    WHERE
        mb.BancoId IS NULL
),
exp_rest_2 AS (
    SELECT e.FechaPago, e.Sucursal, e.IdSuc, e.Segmento, e.FuenteMapeo, e.Rastreo, e.ImporteEsperado
    FROM
        exp_uber_pos e
        LEFT JOIN matched_esp_2_distinct me ON me.FechaPago = e.FechaPago
        AND me.Rastreo = e.Rastreo
    WHERE
        me.Rastreo IS NULL
),

/* =========================================================
ELIMINADO COUNT CORRELACIONADO
========================================================= */

ban_rest_2_count AS (
    SELECT FechaPago, COUNT(*) AS cnt
    FROM ban_rest_2
    GROUP BY
        FechaPago
),
exp_rest_2_count AS (
    SELECT FechaPago, COUNT(*) AS cnt
    FROM exp_rest_2
    GROUP BY
        FechaPago
),

/* =========================================================
MATCH REMANENTE
========================================================= */

uber_candidates AS (
    SELECT
        b.FechaPago,
        b.BancoId,
        b.ImporteBanco,
        e.Rastreo,
        e.Sucursal,
        e.IdSuc,
        e.Segmento,
        e.FuenteMapeo,
        e.ImporteEsperado,
        ABS(
            b.ImporteBanco - e.ImporteEsperado
        ) AS DiffAbs,
        ROW_NUMBER() OVER (
            PARTITION BY
                b.FechaPago,
                b.BancoId
            ORDER BY ABS(
                    b.ImporteBanco - e.ImporteEsperado
                )
        ) AS rn_banco,
        ROW_NUMBER() OVER (
            PARTITION BY
                b.FechaPago,
                e.Rastreo
            ORDER BY ABS(
                    b.ImporteBanco - e.ImporteEsperado
                )
        ) AS rn_esp
    FROM
        ban_rest_2 b
        JOIN exp_rest_2 e ON e.FechaPago = b.FechaPago
        AND ABS(
            b.ImporteBanco - e.ImporteEsperado
        ) <= (
            SELECT max_diff
            FROM uber_params
        )
        JOIN ban_rest_2_count bc ON bc.FechaPago = b.FechaPago
        JOIN exp_rest_2_count ec ON ec.FechaPago = e.FechaPago
),
match_uber_close AS (
    SELECT
        c.FechaPago,
        'UBER' AS Agregador,
        c.Sucursal,
        c.IdSuc,
        c.Segmento,
        c.FuenteMapeo,
        c.Rastreo,
        CAST(c.BancoId AS CHAR) AS BancoIds,
        'UBER remanente match' AS Observacion,
        c.ImporteBanco AS ImporteBancoSuc,
        c.ImporteEsperado AS ImporteEsperadoSuc,
        c.BancoId AS BancoIdNum
    FROM uber_candidates c
    WHERE
        c.rn_banco = 1
        AND c.rn_esp = 1
),

/* =========================================================
MATCH TOTAL
========================================================= */

match_uber AS (
    SELECT
        FechaPago,
        Agregador,
        Sucursal,
        IdSuc,
        Segmento,
        FuenteMapeo,
        Rastreo,
        BancoIds,
        Observacion,
        ImporteBancoSuc,
        ImporteEsperadoSuc
    FROM match_uber_exact
    UNION ALL
    SELECT
        FechaPago,
        Agregador,
        Sucursal,
        IdSuc,
        Segmento,
        FuenteMapeo,
        Rastreo,
        BancoIds,
        Observacion,
        ImporteBancoSuc,
        ImporteEsperadoSuc
    FROM match_uber_fee
    UNION ALL
    SELECT
        FechaPago,
        Agregador,
        Sucursal,
        IdSuc,
        Segmento,
        FuenteMapeo,
        Rastreo,
        BancoIds,
        Observacion,
        ImporteBancoSuc,
        ImporteEsperadoSuc
    FROM match_uber_close
),
uber_negativos AS (
    SELECT
        e.FechaPago,
        'UBER' AS Agregador,
        e.Sucursal,
        e.IdSuc,
        e.Segmento,
        e.FuenteMapeo,
        e.Rastreo,
        NULL AS BancoIds,
        'UBER esperado negativo/0 (pendiente)' AS Observacion,
        NULL AS ImporteBancoSuc,
        e.ImporteEsperado AS ImporteEsperadoSuc
    FROM exp_uber_neg e
),
uber_sobrante_banco AS (
    SELECT
        b.FechaPago,
        'UBER' AS Agregador,
        NULL AS Sucursal,
        NULL AS IdSuc,
        NULL AS Segmento,
        'NO_APLICA' AS FuenteMapeo,
        NULL AS Rastreo,
        CAST(b.BancoId AS CHAR) AS BancoIds,
        'UBER sobrante banco (sin match)' AS Observacion,
        b.ImporteBanco AS ImporteBancoSuc,
        NULL AS ImporteEsperadoSuc
    FROM ban_rest_2 b
        LEFT JOIN (
            SELECT FechaPago, BancoIdNum AS BancoId
            FROM match_uber_close
            GROUP BY
                FechaPago, BancoIdNum
        ) m ON m.FechaPago = b.FechaPago
        AND m.BancoId = b.BancoId
    WHERE
        m.BancoId IS NULL
),
base_all AS (
    SELECT *
    FROM match_uber
    UNION ALL
    SELECT *
    FROM uber_negativos
    UNION ALL
    SELECT *
    FROM uber_sobrante_banco
),
poliza_base AS (
    SELECT
        FechaPago,
        Agregador,
        Sucursal,
        IdSuc,
        Segmento,
        FuenteMapeo,
        Rastreo,
        BancoIds,
        Observacion,
        ROUND(
            COALESCE(SUM(ImporteBancoSuc), 0),
            2
        ) AS ImporteBancoSuc,
        ROUND(SUM(ImporteEsperadoSuc), 2) AS ImporteEsperadoRaw
    FROM base_all
    GROUP BY
        FechaPago,
        Agregador,
        Sucursal,
        IdSuc,
        Segmento,
        FuenteMapeo,
        Rastreo,
        BancoIds,
        Observacion
),
poliza_base2 AS (
    SELECT
        pb.*,
        pb.ImporteEsperadoRaw AS ImporteEsperadoSuc,
        ROUND(
            pb.ImporteBancoSuc - COALESCE(pb.ImporteEsperadoRaw, 0),
            2
        ) AS VarCalc,
        CASE
            WHEN pb.Observacion LIKE 'UBER esperado negativo/0%' THEN 'PENDIENTE'
            WHEN pb.ImporteEsperadoRaw IS NULL THEN 'SOBRANTE_EN_BANCO'
            WHEN ABS(
                ABS(
                    ROUND(
                        pb.ImporteBancoSuc - pb.ImporteEsperadoRaw,
                        2
                    )
                ) - p.fee_amt
            ) <= p.tol_fee THEN 'OK_FEE'
            WHEN ABS(
                pb.ImporteBancoSuc - pb.ImporteEsperadoRaw
            ) < 0.02 THEN 'OK'
            ELSE 'CON_DIFERENCIA'
        END AS TipoObs
    FROM poliza_base pb
        CROSS JOIN uber_params p
),
totales AS (
    SELECT
        FechaPago,
        Agregador,
        ROUND(SUM(ImporteBancoSuc), 2) AS TotalBanco,
        ROUND(
            SUM(
                COALESCE(ImporteEsperadoSuc, 0)
            ),
            2
        ) AS TotalEsperado,
        ROUND(SUM(VarCalc), 2) AS VariacionGrupo
    FROM poliza_base2
    GROUP BY
        FechaPago,
        Agregador
)

/* =========================================================
SALIDA FINAL
========================================================= */

SELECT
    pb.BancoIds,
    pb.Agregador,
    pb.FechaPago,
    pb.IdSuc,
    pb.Segmento,
    pb.Sucursal,
    cb.CuentaBanco AS CodigoCuenta,
    cb.NombreBanco AS NombreCuenta,
    pb.ImporteBancoSuc AS Debe,
    0.00 AS Haber,
    pb.FuenteMapeo,
    'BANCO_CARGO' AS TipoLinea,
    pb.Observacion,
    pb.TipoObs AS TipoObservacion,
    pb.ImporteBancoSuc,
    NULL AS ImporteEsperadoSuc,
    CASE
        WHEN pb.VarCalc < 0 THEN pb.VarCalc
        ELSE 0.00
    END AS VariacionSucursalReal,
    CASE
        WHEN pb.VarCalc < 0 THEN ABS(pb.VarCalc)
        ELSE 0.00
    END AS VariacionAplicada,
    t.TotalBanco,
    t.TotalEsperado,
    t.VariacionGrupo,
    pb.Rastreo
FROM
    poliza_base2 pb
    JOIN totales t ON t.FechaPago = pb.FechaPago
    AND t.Agregador = pb.Agregador
    JOIN cta_banco cb
WHERE (
        pb.TipoObs <> 'PENDIENTE'
        OR pb.ImporteBancoSuc <> 0
    )
UNION ALL
SELECT
    pb.BancoIds,
    pb.Agregador,
    pb.FechaPago,
    pb.IdSuc,
    pb.Segmento,
    pb.Sucursal,
    cu.CuentaAgregador AS CodigoCuenta,
    cu.NombreAgregador AS NombreCuenta,
    0.00 AS Debe,
    pb.ImporteBancoSuc AS Haber,
    pb.FuenteMapeo,
    'AGREGADOR_ABONO' AS TipoLinea,
    pb.Observacion,
    pb.TipoObs AS TipoObservacion,
    NULL AS ImporteBancoSuc,
    pb.ImporteEsperadoSuc,
    CASE
        WHEN pb.VarCalc > 0 THEN pb.VarCalc
        ELSE 0.00
    END AS VariacionSucursalReal,
    CASE
        WHEN pb.VarCalc > 0 THEN pb.VarCalc
        ELSE 0.00
    END AS VariacionAplicada,
    t.TotalBanco,
    t.TotalEsperado,
    t.VariacionGrupo,
    pb.Rastreo
FROM
    poliza_base2 pb
    JOIN totales t ON t.FechaPago = pb.FechaPago
    AND t.Agregador = pb.Agregador
    JOIN cta_uber cu;