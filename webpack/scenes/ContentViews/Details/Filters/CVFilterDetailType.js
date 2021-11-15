import React from 'react';
import PropTypes from 'prop-types';
import CVPackageGroupFilterContent from './CVPackageGroupFilterContent';
import CVRpmFilterContent from './CVRpmFilterContent';
<<<<<<< HEAD
=======
import CVContainerImageFilterContent from './CVContainerImageFilterContent';
import CVModuleStreamFilterContent from './CVModuleStreamFilterContent';
import CVErrataIDFilterContent from './CVErrataIDFilterContent';
import CVErrataDateFilterContent from './CVErrataDateFilterContent';
import CVDebFilterContent from './CVDebFilterContent';
>>>>>>> c521239... deb filter

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
