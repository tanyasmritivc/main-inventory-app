-- Item events table: institutional memory layer for items
CREATE TABLE item_events (
  event_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id         UUID NOT NULL REFERENCES items(item_id) ON DELETE CASCADE,
  user_id         UUID NOT NULL,
  event_type      TEXT NOT NULL CHECK (event_type IN ('usage','note','failure','success','restock','photo')),
  content         TEXT,
  quantity_delta  INTEGER,
  image_url       TEXT,
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_item_events_item_id ON item_events(item_id);
CREATE INDEX idx_item_events_user_id ON item_events(user_id);

ALTER TABLE item_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read their own item events"
  ON item_events FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can insert their own item events"
  ON item_events FOR INSERT WITH CHECK (user_id = auth.uid());
