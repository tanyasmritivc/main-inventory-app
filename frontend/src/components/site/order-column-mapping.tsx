"use client";

import { useState } from "react";
import styles from "./supplier-orders.module.css";

export const orderFields = {
  order: "Order number",
  line: "Supplier line ID",
  sku: "SKU",
  name: "Part description",
  quantity: "Quantity purchased",
  pack: "Units per pack",
  status: "Supplier status",
};
type Field = keyof typeof orderFields;
export type Assignment = {
  header: number;
  mapping: Partial<Record<Field, number>>;
} | null;
export type SourceTable = {
  file: string;
  sheet: string;
  header: number;
  suggestions: Partial<Record<Field, number>>;
  records: { number: number; cells: string[] }[];
};

export function OrderColumnMapping({
  table,
  config,
  update,
}: {
  table: SourceTable;
  config: Assignment;
  update: (c: Assignment) => void;
}) {
  const [page, setPage] = useState(0);
  const width = Math.max(...table.records.map((r) => r.cells.length));
  const columns = Array.from({ length: width }, (_, i) => i);
  const headers =
    table.records.find((r) => r.number === config?.header)?.cells || [];
  const data = table.records.filter((r) => r.number > (config?.header || 0));
  const chunk = data.slice(page * 8, page * 8 + 8);
  const label = (i: number) => `${i + 1}. ${headers[i] || "(unnamed)"}`;
  return (
    <section className={styles.panel}>
      <label>
        <span>
          <input
            className={styles.check}
            type="checkbox"
            checked={!!config}
            onChange={(e) =>
              update(
                e.target.checked
                  ? { header: table.header, mapping: { ...table.suggestions } }
                  : null,
              )
            }
          />{" "}
          Include {table.file}
          {table.sheet && " / " + table.sheet}
        </span>
      </label>
      {config && (
        <>
          <label>
            Column heading row
            <select
              value={config.header}
              onChange={(e) => {
                const header = Number(e.target.value);
                setPage(0);
                update({
                  header,
                  mapping:
                    header === table.header ? { ...table.suggestions } : {},
                });
              }}
            >
              <option value={0}>No header row</option>
              {table.records.map((r) => (
                <option key={r.number} value={r.number}>
                  Row {r.number} ·{" "}
                  {r.cells
                    .filter(Boolean)
                    .slice(0, 3)
                    .join(" / ")
                    .slice(0, 100)}
                </option>
              ))}
            </select>
          </label>
          <div className={styles.scroll}>
            <table>
              <caption>Source columns and values</caption>
              <thead>
                <tr>
                  <th>Row</th>
                  {columns.map((i) => (
                    <th key={i}>{label(i)}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {chunk.map((r) => (
                  <tr key={r.number}>
                    <th>{r.number}</th>
                    {columns.map((i) => (
                      <td key={i}>{r.cells[i] ?? ""}</td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {data.length > 8 && (
            <div>
              <button
                type="button"
                disabled={!page}
                onClick={() => setPage((p) => p - 1)}
              >
                Previous rows
              </button>{" "}
              <button
                type="button"
                disabled={(page + 1) * 8 >= data.length}
                onClick={() => setPage((p) => p + 1)}
              >
                Next rows
              </button>
            </div>
          )}
          <div className={styles.grid}>
            {(Object.keys(orderFields) as Field[]).map((field) => (
              <label key={field}>
                {orderFields[field]} column
                <select
                  value={config.mapping[field] ?? ""}
                  onChange={(e) => {
                    const mapping = { ...config.mapping };
                    if (e.target.value === "") delete mapping[field];
                    else mapping[field] = Number(e.target.value);
                    update({ ...config, mapping });
                  }}
                >
                  <option value="">Unassigned</option>
                  {columns.map((i) => (
                    <option
                      key={i}
                      value={i}
                      disabled={Object.entries(config.mapping).some(
                        ([k, v]) => k !== field && v === i,
                      )}
                    >
                      {label(i)}
                    </option>
                  ))}
                </select>
              </label>
            ))}
          </div>
        </>
      )}
    </section>
  );
}
