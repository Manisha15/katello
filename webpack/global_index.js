import React from 'react';
import { addGlobalFill } from 'foremanReact/components/common/Fill/GlobalFill';
import { registerReducer } from 'foremanReact/common/MountingService';

import SystemStatuses from './components/extensions/about';
import RegistrationCommands from './components/extensions/RegistrationCommands';
import ContentTab from './components/extensions/HostDetails/Tabs/ContentTab';
import ContentViewDetailsCard from './components/extensions/HostDetails/Cards/ContentViewDetailsCard';

// import SubscriptionTab from './components/extensions/HostDetails/Tabs/SubscriptionTab';
import TracesTab from './components/extensions/HostDetails/Tabs/TracesTab';
import extendReducer from './components/extensions/reducers';
import rootReducer from './redux/reducers';

registerReducer('katelloExtends', extendReducer);
registerReducer('katello', rootReducer);

addGlobalFill('aboutFooterSlot', '[katello]AboutSystemStatuses', <SystemStatuses key="katello-system-statuses" />, 100);
addGlobalFill('registrationAdvanced', '[katello]RegistrationCommands', <RegistrationCommands key="katello-reg" />, 100);
addGlobalFill('host-details-page-tabs', 'Content', <ContentTab key="content" />, 100);
/* eslint-disable max-len */
// addGlobalFill('host-details-page-tabs', 'Subscription', <SubscriptionTab key="subscription" />, 100);
addGlobalFill('host-details-page-tabs', 'Traces', <TracesTab key="traces" />, 100);

addGlobalFill('details-cards', 'Content View Details', <ContentViewDetailsCard key="content-view-details" />);
