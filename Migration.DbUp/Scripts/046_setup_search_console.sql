-- CREATE TABLE IF NOT EXISTS public.search_console_data (
--                                      id          UUID           DEFAULT gen_random_uuid() PRIMARY KEY,
--                                      site_url    TEXT           NOT NULL,
--                                      data_date   DATE           NOT NULL,
--                                      query       TEXT,
--                                      page        TEXT,
--                                      country     TEXT,
--                                      device      TEXT,
--                                      clicks      INTEGER        NOT NULL DEFAULT 0,
--                                      impressions INTEGER        NOT NULL DEFAULT 0,
--                                      ctr         NUMERIC(10, 6) NOT NULL DEFAULT 0,
--                                      position    NUMERIC(10, 4) NOT NULL DEFAULT 0,
--                                      fetched_at  TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
--                                      UNIQUE (site_url, data_date, query, page, country, device)
-- );
-- 
-- CREATE INDEX IF NOT EXISTS idx_scd_site_date ON public.search_console_data (site_url, data_date DESC);
-- CREATE INDEX IF NOT EXISTS idx_scd_query     ON public.search_console_data (query);
-- CREATE INDEX IF NOT EXISTS idx_scd_page      ON public.search_console_data (page);

CREATE TABLE IF NOT EXIST public.search_console_snapshots (
                                          id            UUID PRIMARY KEY,
                                          site_url      TEXT        NOT NULL,
                                          snapshot_date DATE        NOT NULL,
                                          data          JSONB       NOT NULL,
                                          fetched_at    TIMESTAMPTZ NOT NULL,
                                          UNIQUE (site_url, snapshot_date)
);
CREATE INDEX IF NOT EXISTS idx_scd_date ON public.search_console_snapshots (fetched_at);