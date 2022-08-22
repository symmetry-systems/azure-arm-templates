
import itertools
from azure.identity import ClientSecretCredential, DefaultAzureCredential, ManagedIdentityCredential
from azure.mgmt.authorization import AuthorizationManagementClient
from azure.mgmt.cosmosdb import CosmosDBManagementClient
from azure.mgmt.managementgroups import ManagementGroupsAPI
from azure.mgmt.resource import ResourceManagementClient, SubscriptionClient
from azure.mgmt.sql import SqlManagementClient
from azure.mgmt.storage import StorageManagementClient
from graph_client import MicrosoftGraphClient
import azure.cosmos.cosmos_client as cosmos_client
from msgraph.core import GraphClient
from azure.storage.blob import BlobClient, BlobServiceClient, ContainerClient

def get_token():
    default_scope = "https://graph.microsoft.com/.default"
    credential = DefaultAzureCredential(managed_identity_client_id='d7d9b76e-9cba-488a-a360-83925d611c66')
    token = credential.get_token(default_scope)
    return token[0]

def get_credentials(client_id):
    credentials = ManagedIdentityCredential(client_id)

def validate_graph_read(client_id):
    credentials = get_credentials(client_id)
    client = MicrosoftGraphClient(adapter=None, credential=credentials)
    first_n = itertools.islice(client.iter_users(), 2)
    assert len(first_n) == 2, 'Fetching Users not working' 

def validate_subscription_read(client_id):
    credentials = get_credentials(client_id)
    subscriptions_client = SubscriptionClient(credential=credentials)
    subs = [s for s in subscriptions_client.subscriptions.list()]
    assert len(subs) > 0, 'Fetching subscription list not working' 

def validate_blob_container_read(client_id, account_name):
    credentials = get_credentials(client_id)
    account_url="https://{}.blob.core.windows.net".format(account_name)
    blob_client = BlobServiceClient(credential=credentials, account_url=account_url,max_chunk_get_size=4 * 1024 * 1024,)
    container_list = blob_client.list_containers()
    containers = [c for c in container_list]
    assert len(containers) > 0, 'Fetching containers for storage account {} not working'.format(account_name)

def validate_cosmosdb_read(client_id, sub_id):
    credentials = get_credentials(client_id)
    cosmos = CosmosDBManagementClient(credential=credentials,subscription_id=sub_id)
    dbs_iter = cosmos.database_accounts.list()
    dbs = [db for db in dbs_iter]
    db = dbs[0]
    client = cosmos_client.CosmosClient('https://{}.documents.azure.com:443/'.format(db.name), credentials)
    databases = [d for d in client.list_databases()]
    assert len(databases) > 0, 'Zero databases found in a cosmos account'
    db = client.get_database_client(databases[0]['id'])
    containers = [c for c in db.list_containers()]
    assert len(containers = [c for c in db.list_containers()]) > 0, 'Zero containers found in a cosmos db'
        




