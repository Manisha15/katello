import React from 'react';
import PropTypes from 'prop-types';
import { Modal, ModalVariant } from '@patternfly/react-core';
import { FormattedMessage } from 'react-intl';
import { translate as __ } from 'foremanReact/common/I18n';
import CopyContentViewForm from './CopyContentViewForm';

const CopyContentViewModal = ({
  cvId, cvName, show, setIsOpen,
}) => {
  const description = (
    <FormattedMessage
      id="copy-cv-description"
      values={{ cv: <b>{cvName}</b> }}
      defaultMessage={__('This will create a copy of {cv}, including details, repositories, and filters. Generated data such as history, tasks and versions will not be copied.')}
    />
  );
  return (
    <Modal
      title="Copy content view"
      variant={ModalVariant.small}
      isOpen={show}
      description={description}
      onClose={() => {
        setIsOpen(false);
      }}
      appendTo={document.body}
    ><CopyContentViewForm cvId={cvId} setModalOpen={setIsOpen} />
    </Modal>);
};

CopyContentViewModal.propTypes = {
  cvId: PropTypes.string,
  cvName: PropTypes.string,
  show: PropTypes.bool,
  setIsOpen: PropTypes.func,
};

CopyContentViewModal.defaultProps = {
  cvId: null,
  cvName: null,
  show: false,
  setIsOpen: null,
};

export default CopyContentViewModal;
