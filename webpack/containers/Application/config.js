import { translate as __ } from 'foremanReact/common/I18n';
import Repos from '../../scenes/RedHatRepositories';
import Subscriptions from '../../scenes/Subscriptions';
import UpstreamSubscriptions from '../../scenes/Subscriptions/UpstreamSubscriptions/index';
import SubscriptionDetails from '../../scenes/Subscriptions/Details';
import SetOrganization from '../../components/SelectOrg/SetOrganization';
import WithOrganization from '../../components/WithOrganization/withOrganization';
import ModuleStreams from '../../scenes/ModuleStreams';
import ModuleStreamDetails from '../../scenes/ModuleStreams/Details';
import AnsibleCollections from '../../scenes/AnsibleCollections';
import AnsibleCollectionDetails from '../../scenes/AnsibleCollections/Details';
import ContentViews from '../../scenes/ContentViews';
import ContentViewDetails from '../../scenes/ContentViews/Details';
import Content from '../../scenes/Content';
import ContentDetails from '../../scenes/Content/Details';
import withHeader from './withHeaders';

// eslint-disable-next-line import/prefer-default-export
export const links = [
  {
    path: 'redhat_repositories',
    component: WithOrganization(withHeader(Repos, { title: __('RH Repos') })),
  },
  {
    path: 'subscriptions',
    component: WithOrganization(withHeader(Subscriptions, { title: __('Subscriptions') })),
  },
  {
    path: 'subscriptions/add',
    component: WithOrganization(withHeader(UpstreamSubscriptions, { title: __('Add Subscriptions') })),
  },
  {
    // eslint-disable-next-line no-useless-escape
    path: 'subscriptions/:id([0-9]+)',
    component: WithOrganization(withHeader(SubscriptionDetails, { title: __('Subscription Details') })),
  },
  {
    path: 'organization_select',
    component: SetOrganization,
  },
  {
    path: 'module_streams',
    component: WithOrganization(withHeader(ModuleStreams, { title: __('Module Streams') })),
  },
  {
    path: 'module_streams/:id([0-9]+)',
    component: WithOrganization(withHeader(ModuleStreamDetails, { title: __('Module Stream Details') })),
  },
  {
    path: 'legacy_ansible_collections',
    component: WithOrganization(withHeader(AnsibleCollections, { title: __('Ansible Collections') })),
  },
  {
    path: 'legacy_ansible_collections/:id([0-9]+)',
    component: WithOrganization(withHeader(AnsibleCollectionDetails, { title: __('Ansible Collection Details') })),
  },
  {
    path: 'content_views',
    component: WithOrganization(withHeader(ContentViews, { title: __('Content Views') })),
  },
  {
    path: 'content_views/:id([0-9]+)',
    component: WithOrganization(withHeader(ContentViewDetails, { title: __('Content View Details') })),
    exact: false,
  },
  {
    path: 'content',
    component: WithOrganization(withHeader(Content, { title: __('Content') })),
  },
  {
    path: 'content/:content_type([a-z_]+)',
    component: WithOrganization(withHeader(Content, { title: __('Content') })),
  },
  {
    path: 'content/:content_type([a-z_]+)/:id([0-9]+)',
    component: WithOrganization(withHeader(ContentDetails, { title: __('Content Details') })),
  },
];
