import { FormEvent, useEffect, useMemo, useState, type CSSProperties } from "react";
import type {
  SchoolPlatformSummary,
  TenantPlatformSummary,
} from "../../../packages/contracts/src";

type AuthUser = {
  id: string;
  email: string;
  fullName: string;
  role: string;
  tenantId?: string | null;
  schoolId?: string | null;
  campusId?: string | null;
};

type LoginResponse = {
  accessToken: string;
  refreshToken: string;
  user: AuthUser;
};

const STORAGE_KEY = "offline-school-saas-admin-session";
const DEFAULT_API_BASE_URL = "http://localhost:3000";

type SessionState = {
  apiBaseUrl: string;
  accessToken: string;
  refreshToken: string;
  user: AuthUser;
};

function App() {
  const [session, setSession] = useState<SessionState | null>(() => {
    const raw = window.sessionStorage.getItem(STORAGE_KEY);
    if (!raw) {
      return null;
    }
    try {
      return JSON.parse(raw) as SessionState;
    } catch {
      window.sessionStorage.removeItem(STORAGE_KEY);
      return null;
    }
  });
  const [apiBaseUrl, setApiBaseUrl] = useState(
    session?.apiBaseUrl ?? DEFAULT_API_BASE_URL,
  );
  const [tenants, setTenants] = useState<TenantPlatformSummary[]>([]);
  const [selectedTenantId, setSelectedTenantId] = useState<string | null>(null);
  const [schools, setSchools] = useState<SchoolPlatformSummary[]>([]);
  const [isLoadingTenants, setIsLoadingTenants] = useState(false);
  const [isLoadingSchools, setIsLoadingSchools] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    if (!session) {
      return;
    }

    let cancelled = false;
    setIsLoadingTenants(true);
    setErrorMessage(null);

    fetch(`${session.apiBaseUrl}/platform-admin/tenants`, {
      headers: {
        Authorization: `Bearer ${session.accessToken}`,
      },
    })
      .then(async (response) => {
        if (!response.ok) {
          throw new Error(await extractError(response));
        }
        return (await response.json()) as TenantPlatformSummary[];
      })
      .then((items) => {
        if (cancelled) {
          return;
        }
        setTenants(items);
        setSelectedTenantId((current) => current ?? items[0]?.id ?? null);
      })
      .catch((error: Error) => {
        if (!cancelled) {
          setErrorMessage(error.message);
        }
      })
      .finally(() => {
        if (!cancelled) {
          setIsLoadingTenants(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [session]);

  useEffect(() => {
    if (!session || !selectedTenantId) {
      setSchools([]);
      return;
    }

    let cancelled = false;
    setIsLoadingSchools(true);
    setErrorMessage(null);

    fetch(`${session.apiBaseUrl}/platform-admin/tenants/${selectedTenantId}/schools`, {
      headers: {
        Authorization: `Bearer ${session.accessToken}`,
      },
    })
      .then(async (response) => {
        if (!response.ok) {
          throw new Error(await extractError(response));
        }
        return (await response.json()) as SchoolPlatformSummary[];
      })
      .then((items) => {
        if (!cancelled) {
          setSchools(items);
        }
      })
      .catch((error: Error) => {
        if (!cancelled) {
          setErrorMessage(error.message);
        }
      })
      .finally(() => {
        if (!cancelled) {
          setIsLoadingSchools(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [selectedTenantId, session]);

  const selectedTenant = useMemo(
    () => tenants.find((tenant) => tenant.id === selectedTenantId) ?? null,
    [selectedTenantId, tenants],
  );

  function persistSession(nextSession: SessionState | null) {
    setSession(nextSession);
    if (nextSession) {
      window.sessionStorage.setItem(STORAGE_KEY, JSON.stringify(nextSession));
      setApiBaseUrl(nextSession.apiBaseUrl);
      return;
    }
    window.sessionStorage.removeItem(STORAGE_KEY);
    setTenants([]);
    setSchools([]);
    setSelectedTenantId(null);
  }

  async function handleLogin(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setErrorMessage(null);

    const formData = new FormData(event.currentTarget);
    const baseUrl = String(formData.get("apiBaseUrl") || DEFAULT_API_BASE_URL).trim();
    const email = String(formData.get("email") || "").trim();
    const password = String(formData.get("password") || "");

    const response = await fetch(`${baseUrl}/auth/login`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        email,
        password,
        deviceFingerprint: "saas-admin-web-session",
      }),
    });

    if (!response.ok) {
      setErrorMessage(await extractError(response));
      return;
    }

    const payload = (await response.json()) as LoginResponse;
    if (payload.user.role !== "support_admin") {
      setErrorMessage("This surface is restricted to support_admin accounts.");
      return;
    }

    persistSession({
      apiBaseUrl: baseUrl,
      accessToken: payload.accessToken,
      refreshToken: payload.refreshToken,
      user: payload.user,
    });
  }

  if (!session) {
    return (
      <main className="login-layout">
        <section className="login-card">
          <p className="eyebrow">Platform operations</p>
          <h1>Offline School SaaS Admin</h1>
          <p className="lede">
            Tenant provisioning, school rollout status, and support-safe platform
            visibility without school operational data.
          </p>
          <form className="login-form" onSubmit={handleLogin}>
            <label>
              API base URL
              <input
                defaultValue={apiBaseUrl}
                name="apiBaseUrl"
                placeholder={DEFAULT_API_BASE_URL}
                type="url"
              />
            </label>
            <label>
              Email
              <input name="email" placeholder="support@example.com" type="email" />
            </label>
            <label>
              Password
              <input name="password" type="password" />
            </label>
            {errorMessage ? <p className="error-banner">{errorMessage}</p> : null}
            <button type="submit">Sign in</button>
          </form>
        </section>
      </main>
    );
  }

  return (
    <main className="app-shell">
      <header className="hero-panel">
        <div>
          <p className="eyebrow">Support admin only</p>
          <h1>SaaS rollout control</h1>
          <p className="lede">
            Tenant and school registration state, campus rollout coverage, and
            platform account status.
          </p>
        </div>
        <div className="session-card">
          <strong>{session.user.fullName}</strong>
          <span>{session.user.email}</span>
          <span>{session.apiBaseUrl}</span>
          <button onClick={() => persistSession(null)} type="button">
            Sign out
          </button>
        </div>
      </header>

      {errorMessage ? <p className="error-banner">{errorMessage}</p> : null}

      <section className="metrics-grid">
        <MetricCard
          label="Tenants"
          value={String(tenants.length)}
          accent="var(--accent-one)"
        />
        <MetricCard
          label="Schools"
          value={String(tenants.reduce((sum, tenant) => sum + tenant.schoolCount, 0))}
          accent="var(--accent-two)"
        />
        <MetricCard
          label="Campuses"
          value={String(tenants.reduce((sum, tenant) => sum + tenant.campusCount, 0))}
          accent="var(--accent-three)"
        />
        <MetricCard
          label="Registered campuses"
          value={String(
            tenants.reduce((sum, tenant) => sum + tenant.registeredCampusCount, 0),
          )}
          accent="var(--accent-four)"
        />
      </section>

      <section className="content-grid">
        <article className="panel">
          <div className="panel-heading">
            <h2>Tenant status</h2>
            {isLoadingTenants ? <span className="status-pill">Refreshing</span> : null}
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Tenant</th>
                  <th>Status</th>
                  <th>Schools</th>
                  <th>Campuses</th>
                  <th>Registered</th>
                </tr>
              </thead>
              <tbody>
                {tenants.map((tenant) => (
                  <tr
                    className={tenant.id === selectedTenantId ? "selected-row" : ""}
                    key={tenant.id}
                    onClick={() => setSelectedTenantId(tenant.id)}
                  >
                    <td>
                      <strong>{tenant.name}</strong>
                      <span className="subtle-line">{tenant.contactEmail ?? "No email"}</span>
                    </td>
                    <td>
                      <StatusBadge value={tenant.workspaceStatus} />
                      <span className="subtle-line">{tenant.status}</span>
                    </td>
                    <td>{tenant.schoolCount}</td>
                    <td>{tenant.campusCount}</td>
                    <td>{tenant.registeredCampusCount}</td>
                  </tr>
                ))}
                {!isLoadingTenants && tenants.length === 0 ? (
                  <tr>
                    <td colSpan={5}>No tenants are available for this support account.</td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        </article>

        <article className="panel">
          <div className="panel-heading">
            <div>
              <h2>School rollout</h2>
              <p className="panel-caption">
                {selectedTenant ? selectedTenant.name : "Select a tenant to inspect schools."}
              </p>
            </div>
            {isLoadingSchools ? <span className="status-pill">Loading schools</span> : null}
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>School</th>
                  <th>Workspace</th>
                  <th>Region</th>
                  <th>Campuses</th>
                  <th>Registered</th>
                </tr>
              </thead>
              <tbody>
                {schools.map((school) => (
                  <tr key={school.id}>
                    <td>
                      <strong>{school.name}</strong>
                      <span className="subtle-line">
                        {school.shortName ?? school.schoolType}
                      </span>
                    </td>
                    <td>
                      <StatusBadge value={school.workspaceStatus} />
                      <span className="subtle-line">{school.tenantStatus}</span>
                    </td>
                    <td>{[school.region, school.district].filter(Boolean).join(", ") || "N/A"}</td>
                    <td>{school.campusCount}</td>
                    <td>{school.registeredCampusCount}</td>
                  </tr>
                ))}
                {!isLoadingSchools && schools.length === 0 ? (
                  <tr>
                    <td colSpan={5}>No schools found for the selected tenant.</td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        </article>
      </section>
    </main>
  );
}

function MetricCard(props: { label: string; value: string; accent: string }) {
  return (
    <article className="metric-card" style={{ "--accent": props.accent } as CSSProperties}>
      <span>{props.label}</span>
      <strong>{props.value}</strong>
    </article>
  );
}

function StatusBadge({ value }: { value: TenantPlatformSummary["workspaceStatus"] }) {
  return (
    <span className={`status-badge status-${value}`}>
      {value.split("_").join(" ")}
    </span>
  );
}

async function extractError(response: Response) {
  try {
    const payload = (await response.json()) as {
      error?: { message?: string };
      message?: string;
    };
    return payload.error?.message || payload.message || response.statusText;
  } catch {
    return response.statusText;
  }
}

export default App;
