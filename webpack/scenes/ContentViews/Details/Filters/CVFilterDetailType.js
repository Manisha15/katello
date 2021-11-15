import React from 'react';
import PropTypes from 'prop-types';
import { head } from 'lodash';
import CVPackageGroupFilterContent from './CVPackageGroupFilterContent';
import CVRpmFilterContent from './CVRpmFilterContent';
import CVContainerImageFilterContent from './CVContainerImageFilterContent';
import CVModuleStreamFilterContent from './CVModuleStreamFilterContent';
import CVErrataIDFilterContent from './CVErrataIDFilterContent';
import CVErrataDateFilterContent from './CVErrataDateFilterContent';
import CVDebFilterContent from './CVDebFilterContent';

const CVFilterDetailType = ({
  cvId, filterId, inclusion, type, showAffectedRepos, setShowAffectedRepos, rules,
}) => {
  switch (type) {
    case 'docker':
      return (<CVContainerImageFilterContent
        cvId={cvId}
        filterId={filterId}
        showAffectedRepos={showAffectedRepos}
        setShowAffectedRepos={setShowAffectedRepos}
      />);
    case 'package_group':
      return (<CVPackageGroupFilterContent
        cvId={cvId}
        filterId={filterId}
        showAffectedRepos={showAffectedRepos}
        setShowAffectedRepos={setShowAffectedRepos}
      />);
    case 'rpm':
      return (<CVRpmFilterContent
        cvId={cvId}
        filterId={filterId}
        inclusion={inclusion}
        showAffectedRepos={showAffectedRepos}
        setShowAffectedRepos={setShowAffectedRepos}
      />);
    case 'modulemd':
      return (<CVModuleStreamFilterContent
        cvId={cvId}
        filterId={filterId}
        showAffectedRepos={showAffectedRepos}
        setShowAffectedRepos={setShowAffectedRepos}
      />);
    case 'erratum':
      if (head(rules)?.types) {
        return (<CVErrataDateFilterContent
          cvId={cvId}
          filterId={filterId}
          inclusion={inclusion}
          showAffectedRepos={showAffectedRepos}
          setShowAffectedRepos={setShowAffectedRepos}
        />);
      }
    case 'deb':
      return (<CVDebFilterContent
        cvId={cvId}
        filterId={filterId}
        inclusion={inclusion}
        showAffectedRepos={showAffectedRepos}
        setShowAffectedRepos={setShowAffectedRepos}
      />);
      return (<CVErrataIDFilterContent
        cvId={cvId}
        filterId={filterId}
        showAffectedRepos={showAffectedRepos}
        setShowAffectedRepos={setShowAffectedRepos}
      />);
    default:
      return null;
  }
};

CVFilterDetailType.propTypes = {
  cvId: PropTypes.oneOfType([PropTypes.string, PropTypes.number]),
  filterId: PropTypes.oneOfType([PropTypes.string, PropTypes.number]),
  inclusion: PropTypes.bool,
  type: PropTypes.string,
  showAffectedRepos: PropTypes.bool.isRequired,
  setShowAffectedRepos: PropTypes.func.isRequired,
  rules: PropTypes.arrayOf(PropTypes.shape({ types: PropTypes.arrayOf(PropTypes.string) })),
};

CVFilterDetailType.defaultProps = {
  cvId: '',
  filterId: '',
  type: '',
  inclusion: false,
  rules: [{}],
};

export default CVFilterDetailType;
