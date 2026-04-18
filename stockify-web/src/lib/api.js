const API_BASE = import.meta.env.VITE_API_URL || "";

export async function apiRequest(path, options = {}) {
  const { body, headers, ...rest } = options;
  const isFormData = typeof FormData !== "undefined" && body instanceof FormData;
  const requestBody = body && !isFormData ? JSON.stringify(body) : body;

  const response = await fetch(`${API_BASE}${path}`, {
    credentials: "include",
    headers: {
      ...(body && !isFormData ? { "Content-Type": "application/json" } : {}),
      ...headers,
    },
    body: requestBody,
    ...rest,
  });

  if (response.status === 204) {
    return null;
  }

  const contentType = response.headers.get("content-type") || "";
  const payload = contentType.includes("application/json") ? await response.json() : await response.text();

  if (!response.ok) {
    const message =
      typeof payload === "string" ? payload : payload?.error || payload?.message || "La solicitud fallo";
    throw new Error(message);
  }

  return payload;
}

export function buildApiUrl(path) {
  return `${API_BASE}${path}`;
}
