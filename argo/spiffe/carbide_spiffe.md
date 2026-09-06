Carbide SPIFFE JWT SVID-based Node
Identity
Software Design Document (PLC-L1 SDD)
Revision History
Version Date Modified By Description
0.1 01/14/2026 Binu Ramakrishnan Initial version
0.2 01/22/2026 Binu Ramakrishnan Updated the doc replacing Vault Transit Engine with KV
master-key
0.3 02/02/2026 Binu Ramakrishnan Updated the document to support Launch Layer tenant
JWT-SVIDs
0.4
Stakeholder Approvals
Stakeholder Name Role* Date Approver Comments
Frank Spitulski US arc Feb 12, 2026 v0.3, design on single pub jwks across shards to be
provided in separate doc
Mike Beiter US sec Feb 19, 2026 0.3
Bojan Vukojevic arc Mar 5, 2026 0.3 LGTM
Jozef van Eenber… LL eng Feb 18, 2026 Approved. Will keep working with Binu on LL
requirements
Andrew Forgue US Carbide eng Feb 6, 2026 Approved
Andrew Farmer US Carbide eng Mar 5, 2026 Approved
Matthias Einwag … Carbide arc Feb 13, 2026 Approved
Tareque Hossain … Carbide Rest
eng
Feb 11, 2026 Approved
Kishore Karthike… NKE eng Feb 18, 2026
Revision History
Stakeholder Approvals
1. Introduction
1.1 Purpose
1.2 Definitions and Acronyms
1.3 Scope
1.3.1 Assumptions, Constraints, Dependencies
2. System Architecture
2.1 High-Level Architecture
2.2 Component Breakdown
3. Detailed Design
3.1 Per-tenant Signing Key Provisioning
3.2 Per-tenant SPIFFE Key Bundle Discovery
3.3 JWT-SVID Node Identity Request Flow
3.4 Data Model and Storage
3.4.1 Database Design
3.4.2 Vault Design
3.4.3 Configuration
3.4.4 JWT-SVID Token Format
3.5 Component Details
3.5.1 External/User-facing APIs
3.5.1.1 Metadata Identity API
3.5.1.2 Carbide Register Token Exchange Callback API
3.5.1.3 Token Exchange Callback Endpoint
3.5.1.4 SPIFFE JWKS Endpoint
3.5.1.5 OIDC Discovery URL
3.5.2 Internal APIs:
4. Technical Considerations
4.1 Security
4.2 Performance and Scalability
4.3 Error Handling and Logging
5. Deployment and Operations
6. Development Plan
6.1 Phasing
7. References
8. Appendix
Notes:
01/21/2026
01/23/2026
01/29/2026
1. Introduction
This document serves as the Software Design Document (SDD) for
Latinum SPIFFE Workload Identity SRD . It details the high-level and low-level design
choices, architecture, and implementation details necessary for the development team.
1.1 Purpose
The purpose of this document is to articulate the design of the software system, ensuring all
stakeholders (development, QA, product management) have a shared understanding of the
solution, its components, and their interactions.
1.2 Definitions and Acronyms
Term/Acronym Definition
SDD Software Design Document
API Application Programming Interface
Carbide NVIDIA bare-metal life-cycle management
system
Tenant A Carbide client/org/account that
provisions/manages BM nodes through Carbide
APIs.
DPU Data Processing Unit
Carbide API server A gRPC server deployed as part of Carbide site
controller
Vault Secrets management system (OSS version:
openbao)
Carbide REST server An HTTP REST-based API server that
manages/proxies multiple site controllers
Carbide site controller Carbide control plane services running on a local
K8S cluster
JWT JSON Web Token
SPIFFE SPIFFE is an industry standard that provides
strongly attested, cryptographic identities to
workloads across a wide variety of platforms.
SPIRE A specific open source software implementation
of SPIFFE standard
Term/Acronym Definition
SVID SPIFFE Verifiable Identity Document (SVID). An
SVID is the document with which a workload
proves its identity to a resource or caller.
JWT-SVID JWT-SVID is a JWT-based SVID based on the
SPIFFE specification set.
JWKS A JSON Web Key (JWK) is a JavaScript Object
Notation (JSON) data structure that represents a
cryptographic key. JSON Web Key Set (JWKS)
defines a JSON data structure that represents a
set of JWKs.
IMDS Instance Meta-data Service
Launch Layer AI Factory API interface that abstracts BMaaS
(Carbide) and VMaaS
https://gitlab-master.nvidia.com/ncp/dsx/dsx-doc
s/-/tree/main
1.3 Scope
This SDD covers the design for Carbide issuing SPIFFE compliant JWTs to nodes it manages.
This includes the initial configuration, run-time and operational flows. Only node identity related
requirements are addressed in this document.
From a Latinum perspective, Carbide will be configured by Launch Layer with only one tenant,
and Launch Layer (LL) will manage multiple tenants, all sharing the same Carbide tenancy in a
site.
The key requirement for Carbide is to provide a node identity against LL tenants, not Carbide
tenants.
1.3.1 Assumptions, Constraints, Dependencies
● Must implement SPIFFE SVIDs as Carbide node identity
● Must rotate and expire SVIDs
● Must provide configurable audience in SVIDs
● Must enable issuing node identity against Launch Layer tenants
● Must support per-tenant key for signing JWT-SVIDs
● Must produce tokens consumable by Vault.
2. System Architecture
2.1 High-Level Architecture
From a high level, the goal for Carbide is to issue a JWT-SVID identity to the requesting
nodes under Carbide’s management. A Carbide managed node will be part of a tenant
(aka org), and the issued JWT-SVID embodies both tenant and machine identity that
complies with the SPIFFE format.
However there are certain cases such as Latinum, where the actual tenants are managed
by an upper layer called Launch Layer. The LL will create a large single tenancy in
Carbide, and creates/manages another layer of tenancy in LL.
One additional key requirement for Carbide is to facilitate the issuance of a JWT-SVID that
embodies LL tenant identity instead Carbide tenant identity (because a Carbide tenant is
shared by multiple LL tenants). The solution is to offer a webhook for Carbide users (LL in
this case) to intercept the signing request, validate the node identity, map LL tenant with
the node, and issue a new JWT-SVID token. Here is the rough flow:
1. As part of initial tenant registration process with Carbide, LL registers a token
exchange callback endpoint to issue JWT-SVID for the LL node tenants
2. When a LL tenant VM/BM process in a Carbide managed node makes an IMDS
(Meta-data) requests, it calls Carbide-API server requesting JWT-SVID
3. The Carbide-api server validates the node, creates a node assertion token (in the
form of JWT-SVID), and then calls the LL webhook API with node meta-data.
4. The LL API receives and validates the request, lookup its database, and sign a
JWT-SVID and return it to Carbide api server (the caller)
5. The Carbide api server returns this JWT-SVID token to IMDS and then to the LL
tenant process.
Callback registration is optional. If the callback is not registered by the Carbide tenants,
Carbide directly signs JWT-SVIDs and returns it to the node (with the Carbide tenant level
SPIFFE ID). This will simplify the implementation, yet functionally complete.
Figure-1 High-level architecture and flow diagram
1. The Launch Layer VM/BM tenant process frequently makes HTTP requests to the
Carbide meta-data service (IMDS) over a link-local address(169.254.169.254). IMDS is
running inside the DPU as part of the Carbide DPU agent.
2. IMDS in turn makes an mTLS authenticated request to the Carbide site controller gRPC
server to sign a SPIFFE compliant node identity token (JWT-SVID). The gRPC server
pulls the node’s organization_id (tenant id), signing keys (encrypted) from the database.
a. Pull master-key from Vault for decrypting tenant signing private key
b. Pull keys and metadata from the database, decrypt private key and sign
JWT-SVID. The token is returned to Host’s tenant process (implicit, not shown in
the diagram).
3. If a token exchange callback is configured, Carbide calls this API
4. The exchange server pulls the SPIFFE bundle/JWKS from Carbide and validate the
node JWT-SVID
5. Perform LL DB lookup to map the node with LL tenant
6. Perform signing a new JWT-SVID and return it to the LL tenant process in the node
(implicit, not shown in the diagram)
7. The LL tenant process subsequently makes a request to a service (say OpenBao/Vault)
with the LL JWT-SVID token passed in the authentication header.
8. The server fetches the signing public key from LL.
9. The server will validate JWT-SVID (and returns secret in the case of Vault).
2.2 Component Breakdown
The system is composed of the following major components:
Component Description Technologies Used
Responsible
Team/Person
Meta-data service (IMDS) A service part of Carbide DPU
agent running inside DPU,
listening on port 80 (def)
Rust HTTP server listener Carbide team
Carbide API (gRPC) server Site controller Carbide control
plane API server
Rust gRPC Server running on
a K8S cluster
Carbide team
Carbide REST Carbide REST API server, an
aggregator service that controls
multiple site controllers
Golang? Carbide team
Vault Internal Vault service local to
Carbide. Already exists to store
Carbide keys
Open source Vault/OpenBao Carbide team
(configure)
Database Store Carbide node-lifecycle and
accounting data
Postgres Carbide team
Token Exchange Server Exchange Carbide node
JWT-SVIDs with LL tenant
workload JWT-SVIDs
Golang (New component)? Launch Layer
3. Detailed Design
There are three different flows associated with implementing this feature:
1. Per-tenant signing key provisioning: Describes how a new signing key associated
with a tenant is provisioned
2. SPIFFE key bundle discovery: Discuss about how the signing public keys are
distributed to interested parties (verifiers)
3. JWT-SVID node identity request flow: The run time flow used by tenant
applications to fetch JWT-SVIDs from Launch Layer (and Carbide).
Each of these flows are discussed below.
3.1 Per-tenant Signing Key Provisioning
CreateTenantRequest (called from from Launch Layer)
│
▼
┌───────────────────────────────┐
│ 1. Validate request metadata │
└───────────────────────────────┘
│
▼
┌───────────────────────────────┐
│ 2. Create tenant in DB │
│ INSERT INTO tenants │
└───────────────────────────────┘
│
▼
┌───────────────────────────────┐
│ 3. Create Keypair in DB and │
│ encrypt it with Vault │
│ master key │
└───────────────────────────────┘
│
▼
┌───────────────────────────────┐
│ 4. Register Exchange Server │
│ callback API │
│ (LL usecase, optional step) │
└───────────────────────────────┘
│
▼
┌───────────────────────────────┐
│ 5. Return CreateTenantResponse│
└───────────────────────────────┘
Figure-2 Per-tenant signing key provisioning flow
As part of the create tenant request (CreateTenantRequest), we insert step (3) and step (4) to
the existing flow. These steps create a new JWT-SVID signing key pair and register a token
exchange callback API.
┌────────┐ ┌───────────────┐ ┌─────────────┐ ┌──────────┐ ┌─────────────┐
│ Client │ │ Carbide-rest │ │ Carbide API │ │ Database │ │ Vault │
│ │ │ (REST) │ │ (gRPC) │ │(Postgres)│ │ (KV Store) │
└───┬────┘ └──────┬────────┘ └──────┬──────┘ └────┬─────┘ └──────┬──────┘
│ │ │ │ │
│ POST /v2/tenants │ │ │ │
│ {org_id, │ │ │ │
│ org_name} │ │ │ │
│──────────────────►│ │ │ │
│ │ │ │ │
│ │ CreateTenantRequest │ │ │
│ │ (gRPC) │ │ │
│ │──────────────────────►│ │ │
│ │ │ GET master key │ │
│ │ │───────────────────────────────────────►│
│ │ │ │ │
│ │ │ │ Key │
│ │ │◄───────────────────────────────────────│
│ │ │ │ │
│ │ │ │ │
│ │ │ Generate key pair & encrypt with masterkey
│ │ │ │ │
│ │ │ DB add org_id, encrypted-key, exchange-cb
│ │ │──────────────────►│ │
│ │ │ │ │
│ │ │ OK │ │
│ │ │◄──────────────────│ │
│ │ │ │ │
│ │ │ │ │
│ │ │ COMMIT │ │
│ │ │──────────────────►│ │
│ │ │ │ │
│ │ CreateTenantResponse │ │ │
│ │ {org_id, ..} │ │ │
│ │◄──────────────────────│ │ │
│ │ │ │ │
│ 201 Created │ │ │ │
│ {org_id,..} │ │ │ │
│◄──────────────────│ │ │ │
│ │ │ │ │
Figure-3 Per-tenant signing key provision sequence diagram
3.2 Per-tenant SPIFFE Key Bundle Discovery
SPIFFE bundles are represented as an RFC 7517 compliant JWK Set. Carbide exposes the
signing public keys through Carbide-rest OIDC discovery/JWKS endpoints. Services that require
JWT-SVID verification pull public keys to verify token signature. Review sequence diagrams
Figure-4 and 5 for more details.
Note: For LL, we expose two different SPIFFE key bundles - one in LL to validate JWT-SVID
issued by LL and another one by Carbide for validating JWT-SVID issued by Carbide. The figure
4 and 5 is focused on Carbide flow, but similar flows shall exist for LL as well.
┌────────┐ ┌───────────────┐ ┌─────────────┐ ┌──────────┐
│ Client │ │ Carbide-rest │ │ Carbide API │ │ Database │
│(e.g LL)│ │ (REST) │ │ (gRPC) │ │(Postgres)│
└───┬────┘ └──────┬────────┘ └──────┬──────┘ └────┬─────┘
│ │ │ │
│ GET /v2/{site-id}/│ │ │
│ org-id}/.well-known/ │ │
│ openid-configuration│ │ │
│──────────────────>│ │ │
│ │ │ │
│ │ gRPC: GetOidcConfig │ │
│ │ (site_id. org_id) │ │
│ │──────────────────────>│ │
│ │ │ │
│ │ │ SELECT tenant, pubkey
│ │ │ WHERE org_id=? │
│ │ │──────────────────>│
│ │ │ │
│ │ │ Tenant record │
│ │ │ (validates org │
│ │ │ exists) │
│ │ │<──────────────────│
│ │ │ │
│ │ │ ┌─────────────────────────────────┐
│ │ │ │ Build OIDC Discovery Document │
│ │ │ └─────────────────────────────────┘
│ │ │ │
│ │ gRPC Response: │ │
│ │ OidcConfigResponse │ │
│ │<──────────────────────│ │
│ │ │ │
│ 200 OK │ │ │
│ { │ │ │
│ "issuer": "...", │ │ │
│ "jwks_uri": ".", │ │ │
│ ... │ │ │
│ } │ │ │
│<──────────────────│ │ │
│ │ │ │
Figure-4 Per-tenant OIDC discovery URL flow
┌────────┐ ┌───────────────┐ ┌─────────────┐ ┌──────────┐
│ Client │ │ Carbide-rest │ │ Carbide API │ │ Database │
│ │ │ (REST) │ │ (gRPC) │ │(Postgres)│
└───┬────┘ └──────┬────────┘ └──────┬──────┘ └────┬─────┘
│ │ │ │
│ GET /v2/{site}/ │ │ │
│ {org}/.well-known/│ │ │
│ jwks.json │ │ │
│──────────────────►│ │ │
│ │ │ │
│ │ GetSVIDJWKS(site_id, │ │
│ │ org_id) │ │
│ │ (gRPC) │ │
│ │──────────────────────►│ │
│ │ │ │
│ │ │ SELECT * FROM │
│ │ │ tenants WHERE │
│ │ │ org_id=? AND │
│ │ │ site_id=? │
│ │ │──────────────────►│
│ │ │ │
│ │ │ Tenant record │
│ │ │◄──────────────────│
│ │ │ │
│ │ │ │
│ │ │ ┌─────────────────────────────────┐
│ │ │ │ Convert key info to JWKS: │
│ │ │ │ - Generate kid from org+version │
│ │ │ │ - Set other key fields │
│ │ │ └─────────────────────────────────┘
│ │ │ │
│ │ GetSVIDJWKSResponse │ │
│ │ {keys: [...]} │ │
│ │◄──────────────────────│ │
│ │ │ │
│ 200 OK │ │ │
│ Content-Type: │ │ │
│ application/json │ │ │
│ │ │ │
│ {"keys":[{ │ │ │
│ "kty":"RSA", │ │ │
│ "alg":"RS256", │ │ │
│ "use":"jwt-svid",│ │ │
│ "kid":"...", │ │ │
│ "n":"...", │ │ │
│ "e":"AQAB" │ │ │
│ }]} │ │ │
│◄──────────────────│ │ │
│ │ │ │
Figure-5 Per-tenant SPIFFE OIDC JWKS key flow
3.3 JWT-SVID Node Identity Request Flow
This is the core part of this SDD – issuing JWT-SVID based node identity tokens to the tenant
node. The tenant can then use this token to authenticate with other services based on the
standard SPIFFE scheme.
[ Tenant Workload ]
│
│ GET http://169.254.169.254:80/v1/metadata/identity?aud=openbao
▼
[ DPU Carbide IMDS ]
│
│ SignNodeId(..)
▼
[ Carbide API Server ]
│
│ Node JWT-SVID
▼
[ Launch Layer Token Exchange Server Callback API ]
│
│ - Validates Carbide JWT-SVID signature using SPIFFE bundle
│ - Verifies iss, audience, TTL
│ - LL DB lookup to map LL workload/tenant SPIFFE ID / attributes
▼
LL JWT-SVID issued to workload/tenant, routed back through Carbide
Figure-6 Node Identity request flow (with LL callback)
┌──────────┐ ┌───────────┐ ┌───────────┐ ┌──────────┐ ┌───────┐ ┌───────────┐
│ Client │ │ Meta-Data │ │ Carbide │ │ Database │ │ Vault │ │ LL Token │
│ (Host) │ │ Service │ │ API │ │ │ │ │ │ Exchange │
└────┬─────┘ └─────┬─────┘ └─────┬─────┘ └─────┬────┘ └────┬──┘ └──────┬────┘
│ │ │ │ │ │
│ GET /v1/ │ │ │ │ │
│ metadata/ │ │ │ │ │
│ identity │ │ │ │ │
│─────────────>│ │ │ │ │
│ │ │ │ │ │
│ │ ┌──────────────────────┐ │ │ │
│ │ │ Extract machine_id │ │ │ │
│ │ │ from InstanceMetadata│ │ │ │
│ │ │ state │ │ │ │
│ │ └──────────────────────┘ │ │ │
│ │ │ │ │ │
│ │ ┌──────────────────────┐ │ │ │
│ │ │ Generate nonce │ │ │ │
│ │ │ (random 32 bytes) │ │ │ │
│ │ └──────────────────────┘ │ │ │
│ │ │ │ │ │
│ │ gRPC: SignNodeIdentity │ │ │
│ │ {machine_id, nonce} │ │ │
│ │─────────────>│ │ │ │
│ │ │ │ │ │
│ │ │ SELECT * FROM │ │
│ │ │ machines │ │ │
│ │ │ WHERE id=$1 │ │ │
│ │ │─────────────>│ │ │
│ │ │<─────────────│ │ │
│ │ │ (machine) │ │ │
│ │ │ │ │ │
│ │ │ SELECT * FROM │ │
│ │ │ instances │ │ │
│ │ │ WHERE │ │ │
│ │ │ machine_id=$1 │ │
│ │ │─────────────>│ │ │
│ │ │<─────────────│ │ │
│ │ │ (instance + │ │ │
│ │ │ tenant_org)│ │ │
│ │ │ │ │ │
│ │ │ ┌─────────────────────────────────┐ │
│ │ │ │ Build JWT claims: │ │
│ │ │ │ { │ │
│ │ │ │ sub: spiffe://.../{machine_id}│ │
│ │ │ │ aud: launch-layer, │ │
│ │ │ │ iat: now, │ │
│ │ │ │ exp: now + ttl │ │
│ │ │ │ } │ │
│ │ │ └─────────────────────────────────┘ │
│ │ │ │ │ │
│ │ │ GET kv/carbide/master-key│ │
│ │ │──────────────────────────>│ │
│ │ │<──────────────────────────│ │
│ │ │ 200 OK {key: "..."} │ │
│ │ │ │ │ │
│ │ │ ┌─────────────────────────────────┐ │
│ │ │ │ Decrypt tenant private key │ │
│ │ │ │ using master key │ │
│ │ │ │ │ │
│ │ │ │ Sign JWT with decrypted key │ │
│ │ │ │ → carbide-jwt-svid │ │
│ │ │ └─────────────────────────────────┘ │
│ │ │ │ │ │
│ │ │ token-exchange(carbide-jwt-svid) │
│ │ │───────────────────────────────────────>│┌───────────┐
│ │ │ │ │ ││Validate,DB│
│ │ │ │ │ ││map and │
│ │ │ │ │ ││issue new │
│ │ │ │ │ ││LL signed │
│ │ │ │ │ ││JWT-SVID │
│ │ │<───────────────────────────────────────│└───────────┘
│ │ │ 200 OK {ll-jwt-svid} │
│ │ │ │ │ │
│ │ SignNodeIdentityResponse │ │ │
│ │ {ll_jwt_svid, expires_at, │ │ │
│ │ spiffe_id, nonce} │ │ │
│ │<─────────────│ │ │ │
│ │ │ │ │ │
│ 200 OK │ │ │ │ │
│ { │ │ │ │ │
│ access_token: ll-jwt-svid,│ │ │ │
│ issued_token_type, │ │ │ │
│ token_type,│ │ │ │ │
│ expires_in │ │ │ │ │
│ } │ │ │ │ │
│<─────────────│ │ │ │ │
│ │ │ │ │ │
Figure-7 Node Identity request sequence diagram
3.4 Data Model and Storage
3.4.1 Database Design
A new table will be created to store tenant signing key pairs. The private key will be encrypted
with a master key stored in Vault.
tenant_identity_keys
text tenant_organization_id PK
text encrypted_signing_key Vault encrypted private key
text signing_key_public Public key
text svid_sign_callback_url Callback URL
text jwks JSON Web Key Set
3.4.2 Vault Design
Create a new KV path in Vault to store the master-key. This master-key will be used to encrypt
and decrypt the tenant signing keys stored in the Carbide DB’s new tenant_identity_keys
table.
3.4.3 Configuration
The JWT spec and vault related configs are passed to the Carbide API server during
startup through site_config.toml config file.
Shell
JSON
# In site config file (e.g., site_config.toml)
[jwt-svid]
iss = "carbide.nvidia.com"
algorithm = "ES256"
default_aud = "carbide"
token_ttl_seconds = 300
vault_kv_mount = "kv"
vault_kv_path = "carbide/master-key"
tenantid_sign_cb_allow = "*.vmaas.nvidia.com,*.ll.nvidia.co" # SSRF
protection
3.4.4 JWT-SVID Token Format
The subject format comes from the NVIDIA SPIFFE ID specification and the discussions in
Spiffe stuff
Carbide JWT-SPIFFE (passed to Launch Layer):
{
"sub": "spiffe://tenant-1.carbide.nvidia.com/node/machine-121",
"iss": "https://<carbide-rest>/v2/org/org-id/carbide/site/site-id",
"aud": [
"launch-layer-exchange-token-service"
],
"exp": 1678886400,
"iat": 1678882800,
"nbf": 1678882800,
"request-meta-data" : {
"aud": [
"openbao-service"
]
}
}
JSON
The Carbide issues two types of JWT-SVIDs. Though they both are similar in structure
and signed by the same key, the purpose and some fields are different.
a. If the exchange token callback is registered, Carbide issues a JWT-SVID node
identity with aud set to “launch-layer”, validity/ttl limited to 120 seconds and pass
additional request parameters using request-meta-data. This token is then passed
to the callback function (shown in the above example).
b. If no callback is not registered, Carbide issues a JWT-SVID directly to the tenant
process in the Carbide managed node. Here the aud is set to what is passed as
parameters in the IMDS call and ttl is set to 10 minutes (configurable).
Launch Layer JWT-SPIFFE:
{
"sub":
"spiffe://tenant_nca-id>.<sjc-1>.<vmaas_name>.nvidia.com/vm/<instance-uuid>",
"iss": "https://<launch-layer>/v1/org/org-id",
"aud": [
"openbao-service"
],
"exp": 1678886400,
"iat": 1678882800,
}
3.5 Component Details
3.5.1 External/User-facing APIs
Endpoint/Method Component Description Input Parameters Output/Return Value
GET
169.254.169.254:7777/v1/meta-data/
identity?[nounce=<random>&aud=<aud
>]
IMDS (DPU
meta-data
service)
Request JWT-SVID node
identity, called from node
(link-local, not available
outside of node)
nonce=random
(optional)
aud=<aud>
Add HTTP header
Metadata: true
Carbide SPIFFE JWT SVID…
GET
https://<carbide-rest>/v2/org/orgid/carbide/site/site-id/.well-know
n/openid-configuration
Carbide-rest OIDC discovery URL
(public, unauthenticated)
Carbide SPIFFE JWT SVID…
GET
https://<carbide-rest>/v2/org/orgid/carbide/site/site-id/.well-know
n/keys
Carbide-rest Carbide-rest JWKS
endpoint (public,
unauthenticated)
Carbide SPIFFE JWT SVID…
POST
https://<carbide-rest>/v2/org/<org
>/carbide/tenant/register-svid-sig
n-callback
Carbide-rest API to register token
exchange callback URL
{
“siteId”: “uuid”,
“callbackUrl”:
“value”,
“audience”: “value”,
“apiKey”: “value”
}
Carbide SPIFFE JWT SVID…
{
“siteId”: “uuid”,
“callbackUrl”: “value”,
“audience”: “value”,
“apiKeyAdded”: true
}
GET
https://<launch-layer>/v1/org/orgid/carbide/site/site-id/.well-know
n/openid-configuration
Launch Layer OIDC discovery URL for
LL issued JWT-SVID
(public, unauthenticated)
Carbide SPIFFE JWT SVID…
GET
https://<launch-layer>/v1/org/orgid/carbide/site/site-id/.well-know
n/keys
Launch Layer JWKS endpoint for LL
issued JWT-SVID (public,
unauthenticated)
Carbide SPIFFE JWT SVID…
POST
https://<launch-layer>/v1/jwt-svid
/exchange
Launch Layer OAUTH2 exchange token
callback API
grant_type=urn:ietf:pa
rams:oauth:grant-type:
token-exchange
&subject_token=<CARBID
E_NODE_JWT_SVID>
&subject_token_type=ur
n:ietf:params:oauth:to
ken-type:jwt
&requested_token_type=
urn:ietf:params:oauth:
token-type:jwt
&audience=<spiffe://tr
ust-domain/target-serv
ice>
Carbide SPIFFE JWT SVID…
None
None
None
3.5.1.1 Metadata Identity API
Both json and plaintext responses are supported depending on the Accept header. Defaults to
json. The audience query parameter must be url encoded. Multiple audiences are allowed but
discouraged by the SPIFFE spec, so we also support multiple audiences in this API.
Request:
GET
http://169.254.169.254:80/v1/meta-data/identity?aud=urlencode(spiffe://y
our.target.service.com)&aud=urlencode(spiffe://extra.audience.com)
Accept: application/json (or omitted)
Metadata: true
Response:
200 OK
Content-Type: application/json
Content-Length: ...
{
"access_token":"...",
"issued_token_type":
"urn:ietf:params:oauth:token-type:jwt",
"token_type":"Bearer",
"expires_in": ...
}
Request:
GET
http://169.254.169.254:80/v1/meta-data/identity?aud=urlencode(spiffe://y
our.target.service.com)&aud=urlencode(spiffe://extra.audience.com)
Accept: text/plain
Metadata: true
None
None
None
Response:
200 OK
Content-Type: text/plain
Content-Length: ...
eyJhbGciOiJSUzI1NiIs...
3.5.1.2 Carbide Register Token Exchange Callback API
Launch Layer calls this Carbide API to register the token exchange callback API.
Request:
POST
https://<carbide-rest>/v2/org/<org>/carbide/tenant/register-svid-sign-ca
llback
{
“siteId”: “uuid”, // Not needed for Latinum
“callbackUrl”: “value”,
“audience”: “value”, // to include in carbide-jwt-svid
“apiKey”: “value”
}
Response:
{
“siteId”: “uuid”,
“callbackUrl”: “value”,
“audience”: “value”,
“apiKeyAdded”: true
}
None
None
None
3.5.1.3 Token Exchange Callback Endpoint
Request:
POST https://{launch-layer}/v1/jwt-svid/exchange
Content-Type: application/x-www-form-urlencoded
grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Atoken-exchange
&subject_token=...
&subject_token_type=urn%3Aietf%3Aparams%3Aoauth%3Atoken-type%3Ajwt
Response:
200 OK
Content-Type: application/json
Content-Length: ...
{
"access_token":"...",
"issued_token_type":
"urn:ietf:params:oauth:token-type:jwt",
"token_type":"Bearer",
"expires_in": ...
}
The exchange service serves an RFC 8693 token exchange endpoint for swapping SPIRE
issued SVIDs with a tenant specific issuer SVID. See 3.3.7 SPIFFE Exchange Service for
details.
3.5.1.4 SPIFFE JWKS Endpoint
GET
https://<carbide-rest>/v2/org/org-id/carbide/site/site-id/.well-known/jw
ks.json
{
"keys": [{
JSON
"kty": "EC",
"use": "sig",
"crv": "P-256",
"kid": "af6426a5-5f49-44b9-8721-b5294be20bb6",
"x": "SM0yWlon_8DYeFdlYhOg1Epfws3yyL5X1n3bvJS1CwU",
"y": "viVGhYhzcscQX9gRNiUVnDmQkvdMzclsQUtgeFINh8k",
"alg": "ES256"
}]
}
3.5.1.5 OIDC Discovery URL
GET
https://<carbide-rest>/v2/org/org-id/carbide/site/site-id/.well-known/op
enid-configuration
{
"issuer": "https://<carbide-rest>/v2/org/org-id/carbide/site/site-id",
"jwks_uri":
"https://<carbide-rest>/v2/org/org-id/carbide/site/site-id/.well-known/j
wks.json",
"response_types_supported": [
"id_token"
],
"subject_types_supported": [
"public"
],
"id_token_signing_alg_values_supported": [
"ES256",
"ES384",
"ES512",
"EdDSA"
]
}
3.5.2 Internal APIs:
Endpoint/Method Component Description Input Parameters Output/Return Value
gRPC: SignNodeIdentity
{machine_id, nonce}
Carbide API gRPC endpoint used by
IMDS to request JWT-SVIDs
{machine_id,
nonce} + X.509
mTLS
SignNodeIdentityResponse
{token, expires_at, spiffe_id,
nonce}
gRPC: GetOidcConfig
{ org_id }
Carbide API gRPC endpoint proxies
OIDC config from Vault
{ org_id } + X.509
mTLS
OidcConfigResponse
{ json-output }
gRPC: GetOidcJwks
{ org_id }
Carbide API gRPC endpoint proxies
JWKS from Vault
{ org_id } + X.509
mTLS
OidcJwksResponse
{ jwt-svid-json-output }
gRPC:
RegisterTenantIdSignCallback(
org_id string,
exchange_callback_url
string, // callback URL
api_key string //
optional
);
Carbide API gRPC endpoint to register
token exchange callback.
This is called as part of or
after
CreateTenantRequest
{
org_id string,
exchange_callback_u
rl string, //
callback URL
api_key string //
optional
} + X.509 mTLS
Response { status }
4. Technical Considerations
4.1 Security
1. All internal API gRPC calls to Carbide API server use (existing) mTLS for authn/z and
transport security
2. Carbide-rest is served over HTTPS and supports SSO integration
3. The IMDS service is exposed over link-local and is exposed only to the node instance.
The nonce field prevents replay attacks by ensuring each request is unique and fresh,
stopping attackers from reusing valid tokens. Adding Metadata: true HTTP header to
the requests to limit SSRF attacks. In order to ensure that requests are directly intended
for IMDS and prevent unintended or unwanted redirection of requests, requests:
● Must contain the header Metadata: true
● Must not contain an X-Forwarded-For header
Any request that doesn't meet both of these requirements is rejected by the service.
4. Requests to IMDS are limited to 3 requests per second. Requests exceeding this
threshold will be rejected with 429 responses. This prevents any DoS on DPU-agent and
Carbide API server due to frequent IMDS calls.
5. The master keys are stored in the Vault KV store and are used to encrypt tenant signing
keys stored in the Carbide database.
6. Input validation: The input such as machine id will be validated using the database
before issuing the token.
7. Option to filter callback API FQDN and strict TLS server auth to protect Carbide against
SSRF
8. Rate-limiting will be enforced particularly on IMDS to prevent any DoS on DPU-agent
and Carbide API server due to frequent IMDS calls.
4.2 Performance and Scalability
No new services are introduced as part of this feature implementation. The new APIs
introduced are relatively lightweight functions and are not expected to add new
constraints to the Carbide system.
Note: The Launch Layer would need to host a new service to implement the exchange
token service. A Golang based reference implementation is availabe here:
https://gitlab-master.nvidia.com/ncp/vmaas/bao-spiffe-cel
4.3 Error Handling and Logging
● All failures will be logged
● Return appropriate HTTP Status code for HTTP failed requests
● gRPC calls - return errors that align with current Carbide practices.
5. Deployment and Operations
The software will be part of the Carbide and Launch Layer stack deployed to DS9/Latinum,
configured and operated by the Latinum operations team.
6. Development Plan
6.1 Phasing
Week-1 Week-2 Week-3 Week-4 Week-5 Week-6
Carbide API server changes, including DB
IMDS/Metadata service changes
Carbide REST APIs
Carbide end to end test Bug fixes, doc
updates
Launch Layer Token Exchange Service Dev Launch Layer end to
end test
Token Exchange Service Code:
https://gitlab-master.nvidia.com/ncp/vmaas/bao-spiffe-cel
7. References
Latinum SPIFFE Workload Identity SRD
Latinum SPIFFE Workload Identity PLC Arch & Design (SDD)
Latinum - Weekly Security Arch Meeting
Carbide Partitions for Bare Metal Clusters
NVIDIA SPIFFE ID Pattern
8. Appendix
SKIP the rest
Notes:
01/21/2026
Suman Sabbani US Tareque Hossain US Andrew Forgue US Binu Ramakrishnan US
Discussed on Carbide tenancy versus LaunchLayer tenancy (follow up from today’s
Latinum Security meeting).
● It appears that there are two tenancy layers - LaunchLayer (LL) and Carbide layer.
The initial discussion was based on the assumption that the LL has one VMAAS
tenancy with Carbide, and then LL manages another layer of tenancy with the
clients.
● Besides security, I believe the above plan has some limitations - ie if there is only
one VMAAS tenant, then LaunchLayer would not be able to make use of Carbide
VPCs because all LL tenants will be placed under one VMAAS VPC, which i think
would be less ideal situation from a network isolation perspective. In that case LL
has to implement its own VPC layer on top of it.
● The meeting consensus was that Carbide will provide node identity for the tenants
created as part of CreateTenantRequest API. It is up to the caller (e.g. LL) to
decide whether to share one Carbide tenancy across all LL tenants or create 1:1
tenants mapping between LL and Carbide.
● So the larger questions are:
1. Should VMs and BMs get Carbide signed JWT-SVID? The BM use case is
covered in this document. A VM could also get the same JWT-SVID if we
configure the node to pass through IMDS request if both VM (LL) tenant and
Node (Carbide) tenant are the same. If the tenancies are not the same, then
VM IMDS requests shall be intercepted by BM LL/VmaaS-agent (running on
base OS) and request the IMDB with additional VM-id that will be appended
to the sub JWT-SVID (example:
spiffe://tenant-1.carbide.nvidia.com/node/machine-abc123/vm-ll01).
2. Another option (see Figure-8 below) that the LL/vmaas tenant agent running
on the host consumes node identity and exchange it into LL BM or VM
identity (provides clear separation, flexible and extensible). This model is
covered Latinum SPIFFE Workload Identity PLC Arch & Design (SDD)
3. In both cases, from a Carbide perspective, it is up to the upper layer to
decide how to layer the system, and the Carbide implementation provides
the necessary building blocks.
4. Questions on OIDC config URL to use (LL or Carbide-rest URL?). From the
Carbide perspective, we will make it configurable, so this is not a blocker.
Next step: Suman Sabbani US to schedule meeting with LL team (
Jozef van Eenbergen CA Frank Spitulski US Tareque Hossain US et al) to bring clarity.
Carbide Partitions for Bare Metal Clusters
Figure-8: Copied from Latinum SPIFFE Workload Identity PLC Arch & Design (SDD)
01/23/2026
Tareque Hossain US Mike Beiter US Bojan Vukojevic Binu Ramakrishnan US
Suman Sabbani US …
The input received from Bojan was that Carbide will be configured (by LL) with only one
tenant, and LL will manage multiple tenants, all sharing the same Carbide tenancy in a
site.
The key requirement for Carbide is to provide a node identity against LL tenants, not
Carbide tenants. The challenge is that the Carbide tenant is shared between multiple LL
tenants, and Carbide doesn’t possess LL tenant details to issue JWT-SVID to the
requesting node.
—
Proposal (to be discussed in the next meeting):
Since Carbide doesn’t have the required Launch Layer (LL) tenant-machine mapping, one
possible solution is to offer a webhook for Carbide users (LL in this case) to intercept the
request, validate the node identity, and issue a JWT token. Here is the rough flow:
6. As part of initial tenant registration process, LL registers a callback webhook
endpoint to issue JWT-SVID for the LL node tenants
7. When a LL tenant process in a Carbide node makes an IMDS requests, it calls
Carbide-API server requesting JWT-SVID
8. The Carbide-api server validates the node, creates a node assertion token (in the
form of JWT-SVID), and then calls the LL webhook API with node meta-data.
9. The LL API receives the request, lookup its database, and sign a JWT-SVID and
return it to Carbide api server (the caller)
10. The Carbide api server returns this JWT-SVID token to IMDS and then to the
Tenant process.
Callback registration is optional. If the callback is not registered by Carbide tenants,
Carbide directly signs JWT-SVIDs and returns it to the node. This will simplify the
implementation, yet functionally complete. This is also functionally similar to Frank’s VM
based SPIFFE id. The main difference is that the token exchange happens further down
the stack, but from an IMDS caller perspective, there is no difference.
Shell
Rough flow
[ Tenant Workload ]
│
│ GET
http://169.254.169.254:7777/v1/metadata/identity?nounce=45678&aud=openbao
▼
[ DPU Carbide IMDS ]
│
│ SignNodeId(..)
▼
[ Carbide API Server ]
│
│ Node JWT-SVID
▼
[ Launch Layer Token Exchange Server Callback API ]
│
│ - Validates Carbide JWT-SVID signature using SPIFFE bundle
│ - Verifies claims, audience, TTL
│ - LL DB lookup to map LL workload/tenant SPIFFE ID / attributes
Protobuf
▼
LL JWT-SVID issued to workload/tenant, routed back through Carbide
Register Callback API with Carbide gRPC API server, used by LL (an equivalent HTTP API
will be exposed in Carbide-rest):
RegisterTenantIdSignCallback(
tenant_organization_id string,
callback_url string, // callback URL
api_key string // optional
);
Corresponding Carbide REST Call:
Endpoint:
POST /v2/org/<org>/carbide/tenant/svid-sign-callback
Sample request:
{
"siteId": "uuid", // Not needed for Latinum
"exchangeCallbackUrl": "value",
"apiKey": "value"
}
Sample response:
{
"siteId": "uuid",
"exchangeCallbackUrl": "value",
"apiKeyAdded": true
}
None
None
JSON
Carbide Callback API Request Structure example
POST /v1/jwt-svid/exchange
Host: exchange.auth.launchlayer.nvidia.com
Content-Type: application/x-www-form-urlencoded
grant_type=urn:ietf:params:oauth:grant-type:token-exchange
&subject_token=<CARBIDE_NODE_JWT_SVID>
&subject_token_type=urn:ietf:params:oauth:token-type:jwt
&requested_token_type=urn:ietf:params:oauth:token-type:jwt
&audience=<spiffe://trust-domain/target-service>
The exchange service serves an RFC 8693 token exchange endpoint for swapping SPIRE
issued SVIDs with a tenant specific issuer SVID. See 3.3.7 SPIFFE Exchange Service for
details.
Response from Launch Layer SPIFFE Exchange server (the response is opaque to
Carbide)
HTTP/1.1 200 OK
Content-Type: application/json;charset=UTF-8
Cache-Control: no-store
Pragma: no-cache
{
"access_token": "eyJhbGci...[LL-TENANT-JWT-SVID- Content]...z5-kdXjwhw",
"issued_token_type": "urn:ietf:params:oauth:token-type:jwt",
"token_type": "Bearer",
"expires_in": 3600,
}
CARBIDE_NODE_JWT_SVID for Launch Layer aud
{
"sub": "spiffe://tenant-1.carbide.nvidia.com/node/machine-abc123",
"iss": "https://carbide-rest.nvidia.com/v2/provider/org-12345",
"aud": "launchlayer-spire-exchange-server",
None
"machine_id": "machine-abc123",
"organization_id": "org-12345",
"site_id": "ytl-01",
"iat": 1737043200,
"exp": 1737046800
}
Notes
01/29/2026
Mike Beiter US Bojan Vukojevic Frank Spitulski US Binu Ramakrishnan US
The above proposal is agreed, and Binu Ramakrishnan US will be updating this
document for the final review/approval.
Feedback Notes
From Mike on rate limiting.
A tenant can run many client services on the VM, which require SVIDs. In
NVIDIA, we usually only run one (the vault agent) and usually do not renew
after (because it keeps a session), which gives us a lower SoL boundary of "1
SVID per VM".
However, I agree that other tenants may run more clients and refresh more often
(eg every 5 mins as you suggest).
What should we assume for number of clients? This is somewhat speculative, we
should make an educated guess.
We run 1 VM per host in the first drop of DSX SW.
As per current plan, we will "never" have vGPU support, which means up to 8 VMs
for current HW designs per host.
Although unlikely now, future plans may allow vGPU, which adds yet another
multiplier (2 or 4?) - and we should consider that scenario.
I suggest estimate lower boundaries and upper boundaries based on these
configurations.
We can then decide on reasonable rate limits based on these estimates.