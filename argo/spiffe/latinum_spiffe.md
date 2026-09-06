Latinum SPIFFE Workload Identity
PLC-L1: Basic PLC: Software Requirements Document
Documentation Control
Item Description
Title Latinum SPIFFE Workload Identity
Author(s) Frank Spitulski US
Revision Oct 10, 2025
State Development <Development, Baselined, Released for Approval, Approved>
Reviewed in <tool>
PLC-L1 SRD
Template Revision
SWE-PLC-L1-001-BasicPLC-SRD-TMPL, Oct.5, 2023
Approvers
Date Name Notes
<month dd, yyyy> <Full Name> <Brief description.>
Reviewers
(NOTE: Please ensure that reviewers include:
● impacted BUs (Business Units) or other NVIDIA product teams, as needed.
● internal representatives for customers or partners (e.g. ISVs) to ensure that requirement or API
changes do not impact applications.)
Date Name Notes
<month dd, yyyy> Cam Moore US <Brief description.>
Bojan Vukojevic
Jan 13, 2026 Mike Beiter US
Mike Moore US
Jozef van Eenbergen CA
Girish Moodalbail US
Kishore Karthikeyan US
Paolo Fiorini US
Brad Vernon US
Nir Paz US
Person
Revision History
Date Author Summary of Change
Oct 10, 2025 Frank Spitulski US initial
Jan 13, 2026 Mike Beiter US
Added clarifications for the host workload ID use
case
Table of Con
tents Introduction
4
O
v
e
rvi
e
w
4
A
s
s
u
m
p
ti
o
n
s
4
C
o
n
s
t
r
ain
t
s
4
D
e
p
e
n
d
e
n
cie
s
4
D
e
fi
niti
o
n
s
,
A
c
r
o
n
y
m
s
,
A
b
b
r
evi
a
ti
o
n
s
5
R
e
f
e
r
e
n
c
e
s
6
U
s
e
C
a
s
e
s
7
R
e
q
u
i
r
e
m
e
n
t
s
8
1 Introduction
1.1 Overview
Why is the project being developed?
We are in need of a cross DC federatable identity for the workloads running in the DS9 Latinum project.
What problem does it solve?
Secure Workload Identity and Attestation system for KubeVirt Virtual Machine Instances (VMIs) and pods
running within a Kubernetes cluster. The system leverages SPIFFE/SPIRE to provide cryptographically
verifiable identities (SVIDs) to applications running inside the VM, enabling secure authentication.
What are the main functions of the project?
The system utilises several DaemonSets (SPIRE Agent, socat) running on the worker Kubernetes nodes,
and a dedicated sidecar (Metadata Service) within the VMI pod to bridge the Workload API socket. The
design provides a unified identity solution for both pod and VM workloads.
Who are the primary stakeholders?
Product Security Team, DSX Operators
Who is developing the project?
Latinum Team under Cam Moore US
1.2 Assumptions
SDN Trust: The underlying Software Defined Network (SDN, ie. OVN) guarantees that the source IP
address of the VM is not spoofed during the call to the Metadata Service.
Kubevirt Bridge Trust: no other VMs are able to access the kubevirt pod local l2 bridge network.
SPIRE Default Behavior: The standard, default configurations of the SPIRE Agent and SPIRE Server are
sufficient for node attestation and SVID minting logic.
1.3 Constraints
Workload Attestor Input: The sole input mechanism for the SPIRE Workload Attestor is the Process ID
(PID) of the application calling the Workload API socket, necessitating the socat sidecar.
VM Network Isolation: Daemons requiring K8s API access (SPIRE Agent) cannot be run as sidecars within
the VMI pod due to the need for cluster network access and the inability for the VM to communicate
with them via UDN as a sidecar.
VMs are unable to access the cluster network.
A sidecar may however use a daemonset to proxy to specific k8s network resources using Unix domain
sockets.
1.4 Dependencies
Team or Company Deliverable
SDN team Static IP Routing to Daemonset on UDN (169.254.169.254)
1.5 Definitions, Acronyms, Abbreviations
Term or Abbreviation Description
SVID SPIFFE Verifiable Identity Document. A cryptographically verifiable identity
used for authentication.
SPIFFE Secure Production Identity Framework for Everyone. A set of standards for
universal identity.
SPIRE SPIFFE Runtime Environment. The open-source system implementing the
SPIFFE specifications.
VMI Virtual Machine Instance (KubeVirt)
UDN User Defined Network. The network interface used by the VM to
communicate with the host/metadata service.
PID Process ID. Used by the SPIRE Workload Attestor as the primary
authentication input.
DaemonSet A Kubernetes controller that ensures a copy of a Pod is running on every
node in a cluster.
socat A command-line utility used as a sidecar to establish a bi-directional relay
between the Workload API socket and the Workload Attestor.
Workload Attestor The component within the SPIRE Agent responsible for verifying the
identity of the calling workload (PID check).
Metadata Service The local service (DaemonSet) that the VM calls to request its SVID. It
performs IP-to-Pod lookup via the K8s API.
SSA Starfleet Service Accounts, an OAuth2 compatible issuer for service to
service auth.
1.6
R
e
f
e
r
e
n
c
e
s
S
W
E
N
u
m
b
e
r In
p
u
t
W
o
r
k
P
r
o
d
u
c
t
R
e
v
i
s
i
o
n
L
o
c
a
ti
o
n
n
/
a
S
D
D
0.2
L
a
ti
n
u
…
2 Use Cases
The following table lists the use cases for this project/feature.
Use Case Description
Secrets Engine
Authentication
Workloads should be able to log into a secrets management service (ie.,
OpenBao or NVault) with their identity token (SVID).
Pod Resource Identity Control Plane Service Pods need an SVID
VM Resource Identity VM Workloads need an SVID
SSA Authentication Workloads should be able to log into SSA with their identity token (SVID)
Dynamic audience
Workloads should be able to scope their identity proof to a specific
audience
3 Requirements
Feature owners and reviewers shall consider the following Requirement Types. See guidelines for the
descriptions. All types that apply to the feature shall be documented in the 4-column table below;
once it gets populated, this instructive table shall be removed from this document.
●Functional Requirements
●Non-Functional Requirements
●Interface Requirements
●Safety Requirements
●KPI Requirements
●Platform Requirements
●Security Requirements
●Legal and Standards Requirements
●Telemetry Requirements
●Backward Compatibility
Requirements
●Virtualization Requirements
●Test Automatability Requirements
The following table lists the requirements for this project/feature.
ID Title Description Type
REQ-1
Unique Identity Must provision a SPIFFE Verifiable Identity
Document (SVID-JWT) identifying a running
workload.
Functional
REQ-2
Verifiable Identity Must expose a public key endpoint for external and
internal validation of SVIDs.
Functional
REQ-3
Workload Identity SVID-JWT’s subject must be tied to the workload’s
pod.
Functional
REQ-3a
Expiration SVIDs must eventually expire with reasonable
proximity to the expiration of the host / pod / VM
that they are attesting. SVIDs must not survive
longer than 5 minutes after the attested workload
terminated (5 minute JWT lifetime).
Functional
REQ-4
Meaningful Identity SVID-JWT’s subject must indicate resource, tenant,
product, resource-type, and resource-id as per this
document
Functional
REQ-5
Dynamic Audience SVID-JWT’s audience must be configurable per
request. The requesting client decides what
audience it wants. The audience is a set, and more
than one element is allowed. The service may add
certain default elements to that set.
Functional
ID Title Description Type
REQ-6
Claims The SPIFFE server may inject a set of claims into the
SVID. Claims is a key/value map with zero or more
keys (the claims field is always present, even if
empty).
Claims are fully controlled by the SPIFFE backend,
the requesting client cannot influence them when it
requests the SVID.
REQ-7
Pod Identity
Provisioning
Must provision a SPIFFE Verifiable Identity
Document (SVID-JWT) to control plane applications
running as containers in pods.
Functional
REQ-8
VM Identity
Provisioning
Must provision a SPIFFE Verifiable Identity
Document (SVID-JWT) to applications running inside
a KubeVirt VM.
Functional
REQ-8a
Host Identity
Provisioning
Must provision a SPIFFE Verifiable Identity
Document (SVID-JWT) to applications running inside
a physical host.
Functional
REQ-9
Metadata Service
Interface
Must expose a HTTP metadata service at an isolated
IP (169.254.169.254) that a host / pod / VM can call
to request its identity token.
Functional
REQ-10
CSRF / SSRF
protection
The metadata service must protect itself against
CSRF / SSRF attacks. APIs must be POST or PUT only,
and the service must reject requests with
Forwarded-For headers, and all requests coming
from an unknown or different node IP source. The
service must further limit request size to 1KB.
Functional
REQ-11
IP injection protection The metadata service must ensure that the TTL of
the IP packet it receives is “1”.
Functional
REQ-12
Local Traffic Only The Metadata Service’s metadata endpoint must be
inaccessible from outside of the node (ie. local
traffic policy)
Security
REQ-13
Host / Pod Identity
Resolution
The Metadata Service must uniquely identify the
source of the calling client to its originating host /
pod.
Functional
REQ-14
Per-Tenant
Deployment
The SPIFFE infrastructure (e.g. SPIRE Agent and
Metadata Service instances) must not be shared by
multiple tenants.
Security
ID Title Description Type
REQ-15
Single-VM Support VM based identity must handle identity requests
from exactly one VMI pod even if multiple are
running on the same node.
Functional
REQ-16
Source IP Trust The SDN must guarantee that the source IP of the
client (host, pod, VM) calling the Metadata Service is
not spoofed.
Security
REQ-17
Least Privilege for
Metadata Service
The Metadata Service's credentials must be
restricted to read-only workload / pods list/get
operations on its own node required for workload
lookups (eg. IP-to-Pod lookup).
Security
REQ-18
Identity Minting
Scope
The SPIRE Agent (and by proxy the metadata
service) must not be able to mint SVIDs outside of
workloads registered to that specific node.
Security
REQ-19
Automated
Deployment
Must be deployable by our existing CD (ArgoCD). No
manual intervention.
Non-Functional
REQ-20
Declarative
Configuration
Configuration must be repeatable and checked into
source control.
Non-Functional
REQ-21 Observability
Must produce logs to stdout, prometheus metrics,
and opentelemetry tracing.
Functional
REQ-22 Health Indication
Must expose comprehensive health monitoring
endpoint(s) to allow for K8s health probes to
accurately represent its health state.
Functional
REQ-23
Stateless The on-worker-node daemonsets (Metadata Service
and SPIRE Agent) must not hold a persistent state.
Functional
REQ-24
Secrets Engine Login OpenBao and NVault must be able to consume
SVIDs for login
Functional
REQ-25
SSA Login (P2) Starfleet Service Accounts must be able to consume
SVIDs for login
Functional
REQ-26 SPIFFE Federation SPIRE Server setup must support SPIFFE Federation Functional
REQ-27
ID Title Description Type
Appendix: Documentation Control for This Template
(Maintained by the PLC team and should be removed in the project work product document)
Documentation Control for This Template (Maintained by the PLC team)
Item Description
Title Document Template for Controlled Docs
Author(s) Arieh Cimet, Chong Teoh
Revision July 6, 2022
PLC Doc # SWE-PLC-L1-001-BaselinePLC-SRD-TMPL
State Baseline
Approver list Hiren Upadhyay
Reviewer list PLC Stakeholders (inclusive of QA leads + Automation and WBT leads)
Reviewed In Review Meeting, NVBugs
Revision History of this Template (Maintained by the PLC team)
Revision Author Summary of Changes
Nov 21, 2017
Arieh Cimet,
Chong Teoh
Initial version
Jan 15, 2018 Chong Teoh Added Requirement Type guideline
Jan 25, 2018 Chong Teoh Added Documentation Control table for this template
Jan 30, 2018 Chong Teoh Added Documentation Control and Revision History for document
Jan 31, 2018 Chong Teoh Converted template per SWE-DOC-005-TMPL
Feb 7, 2018 Chong Teoh
Addressed review comments per NVBug 2054769, review meeting,
and comments in template
Feb 15, 2018 Ajay Keswani Added Scoring Guidelines
April 4, 2018 Chong Teoh Fixed formatting per review feedback.
June 5, 2018 Ajay Keswani
Added Clarification that Template Documentation control is
maintained by the PLC team
Removed SWE Doc# from Documentation control
Provided a confluence pointer to Requirement types
Removed scoring guidelines as these will be provided on confluence
Aug 20, 2019 Ajay Keswani Adding Test Automatability Requirements in Section 4
Jan 24, 2020 Ajay Keswani
Adding more specifics under section 1.2 for internal and external
dependencies.
Revision Author Summary of Changes
Feb 8, 2021 Hiren Upadhyay
Changed title from “PLC-L1: Software Requirements Document” to
“PLC-L1: Baseline PLC-L1: Software Requirements Document” in
order to differentiate this template from the one for Cloud PLC.
Changed template file name from “SWE-PLC-L1-001 -SRD-TMPL” to
“SWE-PLC-L1-001-BaseLinePLC-SRD-TMPL”.
July 6, 2022
Andrija
Bosnjakovic,
Jesper van
Engelen, Puquan
Xu
●Reformatted the template to make the styles consistent –
eliminated manual formatting. This is to address NVBug 3471751.
●Removed the section of “APPENDIX A – REQUIREMENT TYPE
GUIDELINE” as it’s a duplication of Section 3.
●Moved the Doc Control tables for this template to the Appendix.
●Also contributed by Eric Hall, Kabriel Robichaux, Renaud Gaubert,
and Hiren Upadhyay.
Sept 1, 2023
Puquan Xu, Hiren
Upadhyay
Added NOTE under Reviewers section.
Oct.5, 2023 Puquan Xu
Address Nvbug 3314702: Change Whitebox and Black Box to Open
Box and Closed Box respectively. Also refer to ReLingo Home -
ReLingo - Confluence (nvidia.com).