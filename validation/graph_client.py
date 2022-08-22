from azure.core.exceptions import ClientAuthenticationError
from msgraph.core import GraphClient


class AzureAdUser:
    """
    Wrapper around returned user identities from the Azure API, allowing us to
    query for common parameters.
    """

    def __init__(self, graph_client, attributes) -> None:
        self.id = attributes["id"]
        self.attributes = attributes
        self.graph_client = graph_client
        self.authentication_methods = None
        self._mfa_enabled = None

    def __repr__(self) -> str:
        return str(self.attributes)

    def __getitem__(self, key):
        """
        Maintain the interface that Azure Entity classes provide by allowing
        indexing into the User attributes.
        """
        return self.attributes[key]

    def get_authentication_methods(self):
        if self.authentication_methods is None:
            all_methods = []
            for methods in self.graph_client.iter_pages(
                "/users/{}/authentication/methods".format(self.id)
            ):
                all_methods.extend(methods)
            self.authentication_methods = all_methods
        return self.authentication_methods

    def is_mfa_enabled(self):
        """Checks if this user instance has MFA enabled.

        NOTE:
        https://docs.microsoft.com/en-us/graph/api/resources/authenticationmethods-overview?view=graph-rest-1.0
        According to above, the MS Graph currently does not support managing
        `phoneAuthenticationMethod` and some other MFA methods so it may be the
        case that we may evaluate MFA enabled as false here but the user has
        some form of MFA enabled. However, those should be the rare cases.
        `fido2AuthenticationMethod`,
        `microsoftAuthenticatorAuthenticationMethod`,
        `windowsHelloForBusinessAuthenticationMethod` MFA methods are supported
        by MS Graph API and thus will be captured by this method.
        """

        if self._mfa_enabled is None:
            supported_mfa_types = [
                "#microsoft.graph.{}".format(s)
                for s in [
                    "fido2AuthenticationMethod",
                    "microsoftAuthenticatorAuthenticationMethod",
                    "windowsHelloForBusinessAuthenticationMethod",
                ]
            ]
            self._mfa_enabled = False
            for method in self.get_authentication_methods():
                method_type = method.get("@odata.type")
                if method_type is not None and method_type in supported_mfa_types:
                    self._mfa_enabled = True
                    break
        return self._mfa_enabled

    def get_attributes(self):
        """Return enriched attributes for the entity as a dictionary."""
        attrs = self.attributes
        if attrs.get("isMFAEnabled", None) is None:
            attrs["isMFAEnabled"] = self.is_mfa_enabled()
        return attrs


class MicrosoftGraphClient:
    """
    This class serves as an interface between the Microsoft APIs. It enables
    easier retrieval and iteration of Microsoft resources.
    """

    # Reflects in the "appOwnerOrganizationId" for apps and service principals.
    MICROSOFT_TENANT_ID = "f8cdef31-a31e-4b4a-93e4-5f571e91255a"
    CONTEXT_KEY = "@odata.nextLink"
    NEXT_LINK_KEY = "@odata.nextLink"
    VALUE_KEY = "value"
    USER_ATTRIBUTES = [
        "accountEnabled",
        "ageGroup",
        "assignedLicenses",
        "assignedPlans",
        "birthday",
        "businessPhones",
        "city",
        "companyName",
        "consentProvidedForMinor",
        "country",
        "createdDateTime",
        "creationType",
        "deletedDateTime",
        "department",
        "displayName",
        "employeeHireDate",
        "employeeId",
        "employeeOrgData",
        "employeeType",
        "externalUserState",
        "externalUserStateChangeDateTime",
        "faxNumber",
        "givenName",
        "hireDate",
        "id",
        "identities",
        "imAddresses",
        "interests",
        "jobTitle",
        "lastPasswordChangeDateTime",
        "legalAgeGroupClassification",
        "licenseAssignmentStates",
        "mail",
        "mailboxSettings",
        "mailNickname",
        "mobilePhone",
        "mySite",
        "officeLocation",
        "onPremisesDistinguishedName",
        "onPremisesDomainName",
        "onPremisesExtensionAttributes",
        "onPremisesImmutableId",
        "onPremisesLastSyncDateTime",
        "onPremisesProvisioningErrors",
        "onPremisesSamAccountName",
        "onPremisesSecurityIdentifier",
        "onPremisesUserPrincipalName",
        "onPremisesSyncEnabled",
        "otherMails",
        "passwordPolicies",
        "passwordProfile",
        "pastProjects",
        "postalCode",
        "preferredDataLocation",
        "preferredLanguage",
        "preferredName",
        "provisionedPlans",
        "proxyAddresses",
        "refreshTokensValidFromDateTime",
        "responsibilities",
        "schools",
        "showInAddressList",
        "skills",
        "signInSessionsValidFromDateTime",
        "state",
        "streetAddress",
        "surname",
        "usageLocation",
        "userPrincipalName",
        "userType",
    ]
    GROUP_ATTRIBUTES = [
        "allowExternalSenders",
        "assignedLicenses",
        "autoSubscribeNewMembers",
        "classification",
        "createdDateTime",
        "description",
        "displayName",
        "groupTypes",
        "hasMembersWithLicenseErrors",
        "hideFromAddressLists",
        "hideFromOutlookClients",
        "id",
        "isSubscribedByMail",
        "isAssignableRole",
        "licenseProcessingState",
        "mail",
        "mailEnabled",
        "mailNickname",
        "onPremisesLastSyncDateTime",
        "onPremisesProvisioningErrors",
        "onPremisesSecurityIdentifier",
        "onPremisesSyncEnabled",
        "preferredDataLocation",
        "proxyAddresses",
        "renewedDateTime",
        "resourceBehaviorOptions",
        "resourceProvisioningOptions",
        "securityEnabled",
        "securityIdentifier",
        "unseenCount",
        "visibility",
        "acceptedSenders",
        "calendar",
        "calendarView",
        "conversations",
        "createdOnBehalfOf",
        "drive",
        "events",
        "memberOf",
        "members",
        "membersWithLicenseErrors",
        "owners",
        "photo",
        "rejectedSenders",
        "sites",
        "threads",
    ]
    APP_ATTRIBUTES = [
        "addIns",
        "api",
        "appId",
        "applicationTemplateId",
        "appRoles",
        "createdDateTime",
        "deletedDateTime",
        "description",
        "disabledByMicrosoftStatus",
        "displayName",
        "groupMembershipClaims",
        "id",
        "identifierUris",
        "info",
        "isDeviceOnlyAuthSupported",
        "isFallbackPublicClient",
        "keyCredentials",
        "logo",
        "notes",
        "oauth2RequiredPostResponse",
        "optionalClaims",
        "parentalControlSettings",
        "passwordCredentials",
        "publicClient",
        "publisherDomain",
        "requiredResourceAccess",
        "signInAudience",
        "spa",
        "tags",
        "tokenEncryptionKeyId",
        "verifiedPublisher",
        "web",
        "createdOnBehalfOf",
        "extensionProperties",
        "owners",
    ]
    SERVICE_PRINCIPAL_ATTRIBUTES = [
        "accountEnabled",
        "addIns",
        "alternativeNames",
        "appDescription",
        "appDisplayName",
        "appId",
        "appOwnerOrganizationId",
        "applicationTemplateId",
        "appRoleAssignmentRequired",
        "appRoles",
        "deletedDateTime",
        "disabledByMicrosoftStatus",
        "displayName",
        "description",
        "homepage",
        "id",
        "info",
        "keyCredentials",
        "loginUrl",
        "logoutUrl",
        "notes",
        "notificationEmailAddresses",
        "oauth2PermissionScopes",
        "passwordCredentials",
        "preferredSingleSignOnMode",
        "replyUrls",
        "servicePrincipalNames",
        "servicePrincipalType",
        "samlSingleSignOnSettings",
        "signInAudience",
        "tags",
        "tokenEncryptionKeyId",
        "verifiedPublisher",
    ]

    def __init__(self, adapter, credential):
        self.adapter = adapter
        self.graph_client = GraphClient(credential=credential)

    def _validate_select(self, select_list, master_list):
        if select_list is None or len(select_list) == 0:
            return None
        elif isinstance(select_list, str):
            all_tokens = [t.strip() for t in select_list.split(",")]
        elif isinstance(select_list, list):
            all_tokens = select_list
        else:
            raise ValueError(
                "'select' condition should either be string or a list of strings."
            )

        known_tokens = [t for t in all_tokens if t in master_list]

        if len(known_tokens) != len(all_tokens):
            pass

        if known_tokens is not None and len(known_tokens) > 0:
            return known_tokens

        raise ValueError(
            "No known user select attributex found in {}".format(select_list)
        )

    def _construct_select_param(self, select_list, master_list):
        validated = self._validate_select(select_list, master_list)
        if validated is not None and len(validated) > 0:
            return "$select={}".format(",".join(validated))
        else:
            return None

    def _construct_top_param(self, limit):
        if limit is not None:
            if isinstance(limit, int):
                return "$top={}".format(limit)
            else:
                raise ValueError(
                    "{} is not a valid limit. It must be an int.".format(limit)
                )
        else:
            return None

    def _construct_url(self, relative_url, select, entities_per_page, entity_attributes):
        params = [
            x
            for x in [
                self._construct_select_param(select, entity_attributes),
                self._construct_top_param(entities_per_page),
            ]
            if x is not None
        ]
        url = "{}?{}".format(relative_url, "&".join(params))
        return url

    def iter_pages(self, url):
        """Iterate through responses returned by the Microsoft API, formatting
        the response and handling errors.

        This method will record errors but will NOT raise exceptions, as to not
        break the flow. No results are returned if an error is encountered.

        Args:
            url: The Microsoft API endpoint to query.
        """
        try:
            response = self.graph_client.get(url, scopes=["https://graph.microsoft.com/.default"])
        except ClientAuthenticationError:
            self.adapter.update_status(
                "warning",
                "Microsoft permissions failure. The associated identity does not have permissions to the {} resource. Please enable and try again.".format(
                    url.split("?")[0]
                ),
            )
            return []

        if response.status_code == 403:
            json = response.json()
            error = json.get("error")
            if error is not None and error.get("code") == "Authorization_RequestDenied":
                # We do not have enough permissions to read AD
                return []
        if response.status_code != 200:
            raise ValueError(
                "Request to {} failed. Status: {}, response: {}".format(
                    url, response.status_code, response.json()
                )
            )
        json = response.json()
        yield json.get(self.VALUE_KEY)
        if json.get(self.NEXT_LINK_KEY) is not None:
            relative_url = json[self.NEXT_LINK_KEY].replace(
                self.graph_client.graph_session.base_url, ""
            )
            yield from self.iter_pages(relative_url)

    def iter_user_pages(self, select=None, users_per_page=None):
        return self.iter_pages(
            self._construct_url("/users", select, users_per_page, self.USER_ATTRIBUTES)
        )

    def iter_directory_audits(self, select=None, audits_per_page=None):
        return self.iter_pages(
            self._construct_url('/auditLogs/directoryaudits', select, audits_per_page, [])
        )
    
    def iter_users(self, select=None, users_per_page=None):
        for user_page in self.iter_user_pages(
            select=select, users_per_page=users_per_page
        ):
            for user in user_page:
                yield AzureAdUser(self, user)

    def iter_group_pages(self, select=None, groups_per_page=None):
        return self.iter_pages(
            self._construct_url("/groups", select, groups_per_page, self.GROUP_ATTRIBUTES)
        )

    def iter_groups(self, select=None, groups_per_page=None):
        for group_page in self.iter_group_pages(
            select=select, groups_per_page=groups_per_page
        ):
            for g in group_page:
                yield g

    def iter_service_principal_pages(self, select=None, principals_per_page=None):
        return self.iter_pages(
            self._construct_url(
                "/servicePrincipals",
                select,
                principals_per_page,
                self.SERVICE_PRINCIPAL_ATTRIBUTES,
            )
        )

    def iter_service_principals(
        self, exclude_ms_owned=False, select=None, principals_per_page=None
    ):
        for sp_page in self.iter_service_principal_pages(
            select=select, principals_per_page=principals_per_page
        ):
            for sp in sp_page:
                if (
                    exclude_ms_owned
                    and sp["appOwnerOrganizationId"] == self.MICROSOFT_TENANT_ID
                ):
                    continue
                else:
                    yield sp

    def iter_application_pages(self, select=None, apps_per_page=None):
        return self.iter_pages(
            self._construct_url(
                "/applications", select, apps_per_page, self.APP_ATTRIBUTES
            )
        )

    def iter_applications(self, select=None, apps_per_page=None):
        for app_page in self.iter_application_pages(
            select=select, apps_per_page=apps_per_page
        ):
            for app in app_page:
                yield app

    def iter_virtual_machine_pages(self, select=None, apps_per_page=None):
        # TODO
        return self.iter_pages(
            self._construct_url(
                "/applications", select, apps_per_page, self.APP_ATTRIBUTES
            )
        )

    def iter_virtual_machines(self, select=None, apps_per_page=None):
        # TODO
        for app_page in self.iter_application_pages(
            select=select, apps_per_page=apps_per_page
        ):
            for app in app_page:
                yield app
    

