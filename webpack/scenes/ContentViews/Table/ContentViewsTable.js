import React, { useState, useCallback } from 'react';
import useDeepCompareEffect from 'use-deep-compare-effect';
import { useSelector, useDispatch } from 'react-redux';
import { omit } from 'lodash';
import { translate as __ } from 'foremanReact/common/I18n';
import { STATUS } from 'foremanReact/constants';
import { Button } from '@patternfly/react-core';
import { TableVariant } from '@patternfly/react-table';
import TableWrapper from '../../../components/Table/TableWrapper';
import tableDataGenerator from './tableDataGenerator';
import getContentViews from '../ContentViewsActions';
import CreateContentViewModal from '../Create/CreateContentViewModal';
import CopyContentViewModal from '../Copy/CopyContentViewModal';
import PublishContentViewWizard from '../Publish/PublishContentViewWizard';
import { selectContentViews, selectContentViewStatus, selectContentViewError } from '../ContentViewSelectors';
import ContentViewVersionPromote from '../Details/Promote/ContentViewVersionPromote';
import getEnvironmentPaths from '../components/EnvironmentPaths/EnvironmentPathActions';
import ContentViewDeleteWizard from '../Delete/ContentViewDeleteWizard';
import getContentViewDetails, { getContentViewVersions } from '../Details/ContentViewDetailActions';
import { hasPermission } from '../helpers';

const ContentViewTable = () => {
  const response = useSelector(selectContentViews);
  const status = useSelector(selectContentViewStatus);
  const error = useSelector(selectContentViewError);
  const [table, setTable] = useState({ rows: [], columns: [] });
  const [rowMappingIds, setRowMappingIds] = useState([]);
  const [searchQuery, updateSearchQuery] = useState('');
  const loadingResponse = status === STATUS.PENDING;
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [copy, setCopy] = useState(false);
  const [cvResults, setCvResults] = useState([]);
  const [cvTableStatus, setCvTableStatus] = useState(STATUS.PENDING);
  const [isPublishModalOpen, setIsPublishModalOpen] = useState(false);
  const [isPromoteModalOpen, setIsPromoteModalOpen] = useState(false);
  const [isDeleteModalOpen, setIsDeleteModalOpen] = useState(false);
  const [actionableCvDetails, setActionableCvDetails] = useState({});
  const [actionableCvId, setActionableCvId] = useState('');
  const [actionableCvName, setActionableCvName] = useState('');
  const [currentStep, setCurrentStep] = useState(1);
  const dispatch = useDispatch();
  const metadata = omit(response, ['results']);
  const { can_create: canCreate = false } = response;

  const openForm = () => setIsModalOpen(true);

  const openPublishModal = (rowInfo) => {
    setActionableCvDetails({
      id: rowInfo.cvId.toString(),
      name: rowInfo.cvName,
      composite: rowInfo.cvComposite,
      version_count: rowInfo.cvVersionCount,
      next_version: rowInfo.cvNextVersion,
    });
    setIsPublishModalOpen(true);
  };

  const openPromoteModal = (rowInfo) => {
    dispatch(getEnvironmentPaths());
    setActionableCvDetails({
      id: rowInfo.cvId.toString(),
      latestVersionId: rowInfo.latestVersionId,
      latestVersionEnvironments: rowInfo.latestVersionEnvironments,
      latestVersionName: rowInfo.latestVersionName,
    });
    setIsPromoteModalOpen(true);
  };

  const openDeleteModal = (rowInfo) => {
    dispatch(getContentViewDetails(rowInfo.cvId));
    dispatch(getContentViewVersions(rowInfo.cvId));
    setActionableCvDetails({
      id: rowInfo.cvId.toString(),
      name: rowInfo.cvName,
      environments: rowInfo.environments,
      versions: rowInfo.versions,
    });
    setIsDeleteModalOpen(true);
  };

  useDeepCompareEffect(
    () => {
      // Prevents flash of "No Content" before rows are loaded
      const tableStatus = () => {
        if (typeof cvResults === 'undefined' || status === STATUS.ERROR) return status; // will handle errored state
        const resultsIds = Array.from(cvResults.map(result => result.id));
        // All results are accounted for in row mapping, the page is ready to load
        if (resultsIds.length === rowMappingIds.length &&
          resultsIds.every(id => rowMappingIds.includes(id))) {
          return status;
        }
        return STATUS.PENDING; // Fallback to pending
      };

      const { results } = response;
      if (status === STATUS.ERROR) {
        setCvTableStatus(tableStatus());
      }
      if (!loadingResponse && results) {
        setCvResults(results);
        setCurrentStep(1);
        const { newRowMappingIds, ...tableData } = tableDataGenerator(results);
        setTable(tableData);
        setRowMappingIds(newRowMappingIds);
        setCvTableStatus(tableStatus());
      }
    },
    [response, status, loadingResponse, setTable, setRowMappingIds,
      setCvResults, setCvTableStatus, setCurrentStep, cvResults, rowMappingIds],
  );

  const onCollapse = (event, rowId, isOpen) => {
    let rows;
    if (rowId === -1) {
      rows = table.rows.map(row => ({ ...row, isOpen }));
    } else {
      rows = [...table.rows];
      rows[rowId].isOpen = isOpen;
    }

    setTable(prevTable => ({ ...prevTable, rows }));
  };

  const actionResolver = (rowData, { _rowIndex }) => {
    // don't show actions for the expanded parts
    if (rowData.parent !== undefined || rowData.compoundParent || rowData.noactions) return null;
    const publishAction = {
      title: __('Publish'),
      onClick: (_event, _rowId, rowInfo) => {
        openPublishModal(rowInfo);
      },
    };

    const promoteAction = {
      title: __('Promote'),
      isDisabled: !rowData.cvVersionCount,
      onClick: (_event, _rowId, rowInfo) => openPromoteModal(rowInfo),
    };

    const copyAction = {
      title: __('Copy'),
      onClick: (_event, _rowId, rowInfo) => {
        setCopy(true);
        setActionableCvId(rowInfo.cvId.toString());
        setActionableCvName(rowInfo.cvName);
      },
    };

    const deleteAction = {
      title: __('Delete'),
      onClick: (_event, _rowId, rowInfo) => openDeleteModal(rowInfo),
    };

    return [
      ...(hasPermission(rowData.permissions, 'publish_content_views') ? [publishAction] : []),
      ...(hasPermission(rowData.permissions, 'promote_or_remove_content_views') ? [promoteAction] : []),
      ...(canCreate ? [copyAction] : []),
      ...(hasPermission(rowData.permissions, 'destroy_content_views') ? [deleteAction] : []),
    ];
  };

  const additionalListeners = new Array(isPublishModalOpen);
  const emptyContentTitle = __("You currently don't have any Content Views.");
  const emptyContentBody = __('A content view can be added by using the "Create content view" button above.');
  const emptySearchTitle = __('No matching content views found');
  const emptySearchBody = __('Try changing your search settings.');

  const { rows, columns } = table;
  return (
    <TableWrapper
      {...{
        rows,
        error,
        metadata,
        emptyContentTitle,
        emptyContentBody,
        emptySearchTitle,
        emptySearchBody,
        actionResolver,
        searchQuery,
        updateSearchQuery,
        additionalListeners,
      }}
      bookmarkController="katello_content_views"
      variant={TableVariant.compact}
      status={cvTableStatus}
      fetchItems={useCallback(getContentViews, [])}
      onCollapse={onCollapse}
      canSelectAll={false}
      cells={columns}
      autocompleteEndpoint="/content_views/auto_complete_search"
      actionButtons={
        <>
          {canCreate &&
            <Button onClick={openForm} variant="primary" aria-label="create_content_view">
              {__('Create content view')}
            </Button>
          }
          <CreateContentViewModal show={isModalOpen} setIsOpen={setIsModalOpen} aria-label="create_content_view_modal" />
          <CopyContentViewModal cvId={actionableCvId} cvName={actionableCvName} show={copy} setIsOpen={setCopy} aria-label="copy_content_view_modal" />
          {isPublishModalOpen &&
            <PublishContentViewWizard
              details={actionableCvDetails}
              show={isPublishModalOpen}
              setIsOpen={setIsPublishModalOpen}
              currentStep={currentStep}
              setCurrentStep={setCurrentStep}
              aria-label="publish_content_view_modal"
            />
          }
          {isPromoteModalOpen &&
            <ContentViewVersionPromote
              cvId={actionableCvDetails.id}
              versionIdToPromote={actionableCvDetails.latestVersionId}
              versionNameToPromote={actionableCvDetails.latestVersionName}
              versionEnvironments={actionableCvDetails.latestVersionEnvironments}
              setIsOpen={setIsPromoteModalOpen}
            />
          }
          {isDeleteModalOpen && <ContentViewDeleteWizard
            cvId={actionableCvDetails.id}
            cvEnvironments={actionableCvDetails.environments}
            cvVersions={actionableCvDetails.versions}
            show={isDeleteModalOpen}
            setIsOpen={setIsDeleteModalOpen}
            currentStep={currentStep}
            setCurrentStep={setCurrentStep}
            aria-label="delete_content_view_modal"
          />}
        </>
      }
    />
  );
};

export default ContentViewTable;
