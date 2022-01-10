import React from 'react';
import PropTypes from 'prop-types';
import CVPackageGroupFilterContent from './CVPackageGroupFilterContent';
import CVRpmFilterContent from './CVRpmFilterContent';

const CVFilterDetailType = ({
  cvId, filterId, inclusion, type,
}) => {
  switch (type) {
    case 'package_group':
      return <CVPackageGroupFilterContent cvId={cvId} filterId={filterId} />;
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
};

CVFilterDetailType.defaultProps = {
  cvId: '',
  filterId: '',
  type: '',
  inclusion: false,
};

export default CVFilterDetailType;
