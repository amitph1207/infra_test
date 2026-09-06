Latinum NKE Spiffe Integration SADD
Revision History
Version Date Modified By Description
0.1 Jan 14, 2026 Kishore Karthikeyan … Initial Draft
Table of Contents
1. Overview
2. Design Scenarios
3. Primary Design: With Carbide
4. Fallback Design: Without Carbide
5. Sequence Diagrams
6. Expected Claims in the SVID
7. MDS, Token, and Key Distribution Requirements
8. References
9. Appendix A: Summary Table
10. Appendix B: Configuration Examples
Reference
● Latinum SPIFFE Workload Identity SRD
● Carbide SPIFFE JWT SVID-based Node Identity SDD
● Latinum - Weekly Security Arch Meeting
1. Overview
This document describes how NKE (NVIDIA Kubernetes Engine) integrates with
SPIFFE/SPIRE for workload identity, specifically focusing on how SVIDs (SPIFFE Verifiable
Identity Documents) enable secure node joining and communication.
1.1 NKE Spiffe identity
NKE is a consumer of SPIFFE identity provided by carbide
In the primary design, Carbide provides the SPIFFE infrastructure (SPIRE server/agent,
SPDM/DPU attestation), and NKE simply consumes the SVID JWT tokens made available
via the Metadata Service (MDS). NKE only implements its own SPIRE infrastructure in
decomposition scenarios where Carbide is not available.
1.2 Goals
● Secure communication between site controller (SWE) and NKE agent using mTLS
● Replace SSH and Kubetrust with standards-based SPIFFE identity
● Credential-less bootstrapping leveraging Carbide's SPDM/DPU attestation
● Support decomposition use cases where Carbide is not present
2. Design Scenarios
Scenario SPIFFE Provider NKE Role MDS SVID Verification
With Carbide (Primary) Carbide Consumer 169.254.169.254
<7777 port>
http://169.254.169.254:77
77/v1/metadata/identity?
nounce=<random>&aud=
<audience>
Carbide's well-known
endpoint
Without Carbide (Fallback) NKE Provider +
Consumer
Not used (direct socket) NKE's SPIRE Server
3. Primary Design: With Carbide
3.1 Architecture Overview
In the primary design, Carbide owns the entire SPIFFE infrastructure:
┌─────────────────────────────────────────────────────────────────────┐
│ Primary Design: With Carbide │
├─────────────────────────────────────────────────────────────────────┤
│ │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ Carbide Layer │ │
│ │ ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ │ │
│ │ │ SPIRE Server │ │ Attestor │ |JWKS Endpoint │ │
│ │ │ │ │ │ │ (well-known) │ │ │
│ │ └───────┬───────┘ └───────────────┘ └───────────────┘ │ │
│ │ │ ▲ │ │
│ │ │ │ │ │
│ │ ┌───────┴───────┐ JWT Verification │ │
│ │ │ SPIRE Agent │ │ │ │
│ │ │ (on host) │ │ │ │
│ │ └───────┬───────┘ │ │ │
│ │ │ │ │ │
│ │ ▼ │ │ │
│ │ ┌───────────────┐ │ │ │
│ │ │ MDS │ │ │ │
│ │ │169.254.169.254│ │ │ │
│ │ └───────┬───────┘ │ │ │
│ └──────────┼──────────────────────────────────────┼───────────┘ │
│ │ │ │
│ │ SVID JWT │ │
│ ▼ │ │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ Managed Host │ │
│ │ ┌───────────────┐ ┌───────────────┐ │ │
│ │ │ NKE Agent │ │ DPU/SPDM │ │ │
│ │ │ │ │ (attested │ │ │
│ │ │ • Fetch JWT │ │ by Carbide) │ │ │
│ │ │ from MDS │ │ │ │ │
│ │ │ • Serve gRPC │ └───────────────┘ │ │
│ │ │ with mTLS │ │ │
│ │ └───────────────┘ │ │
│ └─────────────────────────────────────────────────────────────┘ │
│ ▲ │
│ │ mTLS (SVID JWT) │
│ │ │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ NKE Site Controller │ │
│ │ ┌───────────────┐ ┌───────────────┐ │ │
│ │ │ SWE │ │ CWE │ │ │
│ │ │ │ │ │ │ │
│ │ │ • Get JWT │ │ │ │ │
│ │ │ from MDS │ │ │ │ │
│ │ │ • Verify via │──┼───────────────┼────────────────────── ┼────┤
│ │ │ well-known │ │ │ │ │
│ │ └───────────────┘ └───────────────┘ │ │
│ └─────────────────────────────────────────────────────────────┘ │
│ │
│ NKE Components: Nke agent │
│ │
└─────────────────────────────────────────────────────────────────────┘
NKE Components
NKE Agent
4. mTLS Connection
3. Verify peer JWT SWE Pod
Managed Host
BlueField DPU
SPDM Engine
TPM
optional
1a. SPDM Attestation
(Device Identity Cert)
1b. TPM Attestation
(EKCert) - fallback
Carbide Layer
SPIRE Server
2. Issue SVID JWT
(via MDS)
3. Verify peer JWT
2. Issue SVID JWT
(via MDS)
JWKS Endpoint
/.well-known/jwks
3.2 Component Responsibilities
Component Owner Responsibility
SPIRE Server Carbide Issue SVIDs, manage
registrations, expose JWKS
endpoint
SPIRE Agent Carbide Run on DPU, perform SPDM
attestation, expose MDS
Component Owner Responsibility
DPU/SPDM Attestation Carbide Attest host identity via SPDM
MDS (169.254.169.254) Carbide Serve SVID JWT to local
workloads
JWKS Endpoint Carbide Public well-known endpoint for
JWT verification
NKE Agent NKE Fetch SVID from MDS, serve
gRPC with mTLS
SWE NKE Fetch SVID from MDS, connect
to NKE Agent, verify remote
JWT
3.3 How NKE Uses SVID as Join Token
In the Carbide scenario, NKE uses the SVID JWT for mTLS identity:
1. NKE Agent (Server Side)
○ Fetches its SVID JWT from MDS at 169.254.169.254
○ Uses the JWT to establish its identity in mTLS handshake
○ Verifies client (SWE) JWT using Carbide's well-known JWKS endpoint
2. SWE (Client Side)
○ Fetches its SVID JWT from MDS (or via k8s workload identity)
○ Presents JWT during mTLS connection to NKE Agent
○ Verifies server (NKE Agent) JWT using Carbide's well-known JWKS endpoint
3. Secure Channel for Join Token
○ Once mTLS is established, SWE securely transmits K8s join token
○ No shared secrets or SSH required
3.5 NKE Agent Implementation Requirements
Requirement Description
MDS Client HTTP client to fetch SVID JWT from
http://169.254.169.254:7777/…
Requirement Description
GET
http://169.254.169.254:7777/v1/metadata/iden
tity?nounce=<random>&aud=<audience>
Response:
{
"token": "<SVID-JWT>",
"expires_at": "2026-01-14T12:00:00Z",
"nonce": "45678",
"spiffe_id":
"spiffe://<tenant-id>.<site-id>.carbide.nvid
ia.com/node/{uuid}"
}
JWT Parser Parse and extract claims from SVID JWT
JWKS Client Fetch public keys from Carbide's well-known
endpoint
JWT Verifier Verify JWT signature using JWKS
mTLS Server gRPC server using JWT for identity
Token Refresh Periodically refresh JWT before expiry
4. Fallback Design: Without Carbide
4.1 When This Applies
The fallback design is used in decomposition scenarios where:
● Carbide is not deployed
● No MDS is available
● No Carbide JWKS endpoint exists
● NKE must provide its own SPIFFE infrastructure
Examples: Standalone NKE deployments, bare-metal environments without Carbide,
testing environments.
4.2 Architecture Overview
┌─────────────────────────────────────────────────────────────────────┐
│ Fallback Design: Without Carbide │
├─────────────────────────────────────────────────────────────────────┤
│ │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ NKE Site Controller │ │
│ │ ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ │ │
│ │ │ SPIRE Server │ │ CWE │ │ SWE │ │ │
│ │ │ (NKE-owned) │ │ │ │ │ │ │
│ │ │ │ │ • Sync TPM │ │ • Get SVID │ │ │
│ │ │ • TPM plugin │ │ pubhashes │ │ via k8s_psat│ │ │
│ │ └───────┬───────┘ └───────────────┘ └───────────────┘ │ │
│ │ │ │ │
│ │ ┌───────┴───────┐ │ │
│ │ │ SPIRE Agent │ (DaemonSet, k8s_psat attestation) │ │
│ │ └───────────────┘ │ │
│ └─────────────────────────────────────────────────────────────┘ │
│ │ │
│ │ mTLS (JWT/X.509 SVIDs) │
│ ▼ │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ Managed Host │ │
│ │ ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ │ │
│ │ │ SPIRE Agent │ │ NKE Agent │ │ TPM │ │ │
│ │ │ (NKE-owned) │ │ │ │ │ │ │
│ │ │ │ │ • Get SVID │ │ • EKCert from │ │ │
│ │ │ • TPM attested│ │ via socket │ │ Forge/BMaaS │ │ │
│ │ │ • Unix socket │ │ • Serve gRPC │ │ │ │ │
│ │ └───────────────┘ └───────────────┘ └───────────────┘ │ │
│ └─────────────────────────────────────────────────────────────┘ │
│ │
│ NKE Components: Provider + Consumer │
│ │
└─────────────────────────────────────────────────────────────────────┘
4.3 Component Responsibilities (NKE-Owned)
Component Location Responsibility
SPIRE Server Site Controller Issue SVIDs, manage TPM
pubhash registrations
spire-controller-manager Site Controller K8s operator for SPIRE CRs
SPIRE Agent (k8s_psat) Site Controller Attest pods via ServiceAccount
tokens
SPIRE Agent (TPM) Managed Host Attest host via TPM, expose
Workload API socket
CWE Site Controller Sync TPM pub hashes from
Forge/BMaaS to SPIRE
NKE Agent Managed Host Get SVID from local SPIRE
Agent socket
4.4 TPM EKCert Acquisition
Without Carbide, NKE must obtain TPM EKCerts from the underlying infrastructure:
Infrastructure EKCert Source
Forge Forge API
BMaaS BMaaS API
On-premises Direct TPM query or manual provisioning
4.5 Key Differences Carbide provided Attestation vs NKE
provided
Aspect With Carbide Without Carbide
SPIRE Server Carbide-owned NKE-owned
Aspect With Carbide Without Carbide
SPIRE Agent Carbide-owned NKE-owned
Attestation Carbide performs DPU
based attestation
NKE performs TPM based
attestation
SVID Delivery MDS (169.254.169.254) Unix socket
SVID Type JWT JWT ( or x.509)
Verification Carbide JWKS endpoint NKE SPIRE trust bundle
EKCert Source Carbide manages NKE queries Forge/BMaaS
5. Sequence Diagrams
5.1 Primary Design: SVID Flow with Carbide
BlueField DPU
(SPDM Engine)
Carbide
SPIRE Server
Carbide
SPIRE Agent
(on DPU)
Carbide MDS (169.254.169.254)
Host Bootstrap Phase (DPU Attestation)
SPDM Attestation
(Device Identity Cert + Measurements)
Verify device certificate chain
Issue SVID JWT for host
Expose JWT via MDS
NKE Agent Initialization
BlueField DPU
(SPDM Engine)
Carbide
SPIRE Server
Carbide SPIRE Agent (on DPU)
GET /v1/identity/token?aud=swe
NKE Agent
(on host)
Return SVID JWT
Start gRPC server
with JWT identity
SWE Initialization
GET /v1/identity/token?aud=nke-agent
Return SVID JWT
mTLS Connection
10
mTLS Connect
(present JWT)
Carbide JWKS SWE Pod Endpoint
Fetch public keys
JWKS response
Verify SWE JWT
Present Host JWT
Fetch public keys
JWKS response
Verify Host JWT
Secure channel established
gRPC operations over mTLS
15
SWE Pod Carbide JWKS
Endpoint
Carbide MDS
(169.254.169.254) NKE Agent (on host)
5.2 Primary Design: Kubernetes Node Join
5.3 NKE Managed spiffe: Without Carbide
Refer: NKE SPIFFE/SPIRE Host Identity
None
6. Expected Claims in the SVID
6.1 SVID JWT Structure
{
"sub":
"spiffe://tenant-1.ytl-01.carbide.nvidia.com/node/machine-abc123",
"iss":
"https://carbide-rest.nvidia.com/v1/identity/oidc/provider/org-12345",
"aud": "<tbf>",
"machine_id": "machine-abc123",
"organization_id": "org-12345",
"site_id": "ytl-01",
None
"iat": 1737043200,
"exp": 1737046800
}
6.2 Required Claims
Claim Type Required Description
sub string ✅ SPIFFE ID of the workload
iss string ✅ Issuer URL (Carbide JWKS
endpoint)
aud array ✅ Target audience(s) - who can
consume this token
exp number ✅ Expiration time (Unix
timestamp)
iat number ✅ Issued at time (Unix timestamp)
6.3 Optional/Custom Claims (NKE-Specific)
Claim Type Description
machine_id string Unique machine identifier
organization_id string Org/Tenant ID of the tenant
site_id string Site Identifier
6.4 SPIFFE ID Formats
With Carbide:
Trust Domain:
None
<tenant-id>.<site-id>.carbide.nvidia.com
Host Identity:
spiffe://<tenant-id>.<site-id>.carbide.nvidia.com/node/<machine-id>
Example:
spiffe://tenant-1.sjc-01.carbide.nvidia.com/node/machine-8e45c079-100d-42
73-8071-3d679e1a435e
Without Carbide (NKE-owned):
Trust Domain: <tenant-id>.<site-id>.nke.nvidia.com
Host Identity:
spiffe://<tenant-id>.<site-id>.nke.nvidia.com/node/<machine-id>
Service Identity:
spiffe://<trust-domain>/nke-service/<k8s-service-account-name>
6.5 Audience Configuration
The audience claim determines who can verify and accept the JWT:
Scenario Audience Value
NKE Agent serving gRPC spiffe://carbide.nvidia.com/nke/site-workflowengine
SWE connecting to agent spiffe://carbide.nvidia.com/nke/host/*
OpenBao/NVault login openbao, nvvault
None
7. MDS, Token, and Key Distribution Requirements
7.1 Metadata Service (MDS) - Primary Design
Requirement Value
Endpoint http://169.254.169.254:7777
Protocol HTTP (link-local, no TLS needed)
Provider Carbide
Consumer NKE Agent
7.1.1 MDS API (Expected)
GET /v1/metadata/identity?nounce=<random>&aud=<aud>
Response:
{
"token": "<SVID-JWT>",
"expires_at": "2026-01-15T15:30:00Z",
"nonce": "45678",
"spiffe_id":
"spiffe://<tenant-id>.<site-id>.carbide.nvidia.com/node/{uuid}"
}
7.2 JWT Verification - Primary Design
Requirement Value
JWKS Endpoint OIDC Discovery URL:
GET
https://<carbide-rest>/v1/org/<org-id>/carbi
de/site/<site-id>/.well-known/openid-configu
ration
JWKS Endpoint:
Requirement Value
GET
https://<carbide-rest>/v1/org/<org-id>/carbi
de/site/<site-id>/.well-known/keys
Protocol HTTPS (public endpoint)
Provider Carbide
Consumer NKE Agent, SWE
7.2.1 NKE Agent Verification Flow
● Receive JWT from connecting client (SWE)
● Fetch JWKS from Carbide's well-known endpoint
● Verify JWT signature against JWKS
● Validate claims (aud, exp, iss)
● Extract identity from sub claim
7.3 Token Lifecycle
Phase Duration Action
Initial Fetch On startup NKE Agent fetches JWT from
MDS
Refresh Before expiry (e.g., 50% of TTL) Re-fetch from MDS
Verification Per-connection Verify peer JWT via JWKS
7.4 Token Requirements
Requirement Value Rationale
Max JWT Lifetime 5 minutes
<prodsec recommended value -
configurable>
Per Latinum SRD REQ-3a
Renewal Buffer 50% of lifetime Refresh at 2.5 min
Audience Dynamic Client specifies target audience
Claims Immutable Controlled by Carbide, not client
7.5 Security Requirements
ID Requirement Primary Design Fallback Design
SEC-1 No secrets in
bootstrap
MDS is link-local Cloud-init has only trust
bundle
SEC-2 TPM-bound identity Carbide attestation NKE attestation
SEC-3 Short-lived tokens 5 min JWT 5 min JWT
SEC-4 Public key verification Carbide JWKS NKE trust bundle
SEC-5 mTLS for all
communication
JWT-based JWT (or X509)
8. References
8.1 Internal Documents
● SPIFFE ID Design (Trade-offs)
● Latinum SPIFFE Workload Identity SRD
8.2 SPIFFE/SPIRE Documentation
● SPIFFE Concepts
● SPIRE Agent Configuration
● SPIFFE Federation
9. Appendix A: Summary Table
Question Answer
How does NKE use SVID as a join token? SVID JWT provides mTLS identity; join token
transmitted over secure mTLS channel. NKE
Agent and SWE both fetch JWTs from Carbide
MDS.
Expected claims in SVID? sub, iss, aud, exp, iat (required) +
Carbide-controlled custom claims
(machine_id, organization_id, site_id)
MDS requirements? Carbide provides MDS at 169.254.169.254;
NKE is a consumer only
Token verification? Carbide exposes public JWKS endpoint; NKE
verifies JWTs using this endpoint
Without Carbide? NKE runs its own SPIRE server/agent,
performs TPM attestation directly, requires
EKCert from Forge/BMaaS
10. Appendix B: Configuration Examples
None
B.1 NKE SPIRE Agent Configuration (Managed
Host)
Only applicable when Carbide is not present
agent {
data_dir = "/var/lib/spire/agent"
log_level = "INFO"
server_address = "spire-server.nke-site.svc.cluster.local"
None
server_port = "8081"
socket_path = "/run/spire/agent/sockets/spire-agent.sock"
trust_bundle_path = "/etc/spire/bundle.crt"
trust_domain = "nke-site.nke.nvidia.com"
}
plugins {
NodeAttestor "tpm" {
plugin_cmd = "/opt/spire/bin/tpm_attestor_agent"
plugin_data {}
}
KeyManager "disk" {
plugin_data {
directory = "/var/lib/spire/agent"
}
}
WorkloadAttestor "unix" {
plugin_data {}
}
}
B.2 ClusterStaticEntry for Host Registration
apiVersion: spire.spiffe.io/v1alpha1
kind: ClusterStaticEntry
metadata:
name: host-8e45c079-100d-4273-8071-3d679e1a435e
spec:
spiffeID:
"spiffe://nke-site.nke.nvidia.com/host/8e45c079-100d-4273-8071-3d679e1a435e"
parentID: "spiffe://nke-site.nke.nvidia.com/spire/agent/tpm/<tpm-pubhash>"
selectors:
- "unix:uid:0"