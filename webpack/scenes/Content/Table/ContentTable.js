import React, { useState, useCallback } from 'react';
import { useSelector } from 'react-redux';
import { translate as __ } from 'foremanReact/common/I18n';
import { TableVariant, Thead, Tbody, Tr, Th, Td } from '@patternfly/react-table';
import PropTypes from 'prop-types';
import TableWrapper from '../../../components/Table/TableWrapper';
import { getContent } from '../ContentActions';
import { selectContent, selectContentStatus, selectContentError } from '../ContentSelectors';
import SelectableDropdown from '../../../components/SelectableDropdown';
import contentConfig from '../ContentConfig';

const ContentTable = ({ selectedContentType, setSelectedContentType, contentTypes }) => {
  const status = useSelector(selectContentStatus);
  const error = useSelector(selectContentError);
  const response = useSelector(selectContent);
  const [searchQuery, updateSearchQuery] = useState('');
  const { results, ...metadata } = response;

  const { columnHeaders } = contentConfig().find(type =>
    type.names.singular === contentTypes[selectedContentType][0]);

  /* eslint-disable react/no-array-index-key */
  function buildRows(details) {
    const rows = [];
    if (details) {
      columnHeaders.forEach((header, index) =>
        rows.push(<Td key={index}>{header.getProperty(details)}</Td>));
    }
    return rows;
  }

  return (
    <TableWrapper
      {...{
        metadata,
        searchQuery,
        updateSearchQuery,
        error,
        status,
      }}
      key={selectedContentType}
      variant={TableVariant.compact}
      autocompleteEndpoint={`/${contentTypes[selectedContentType][1]}/auto_complete_search`}
      emptyContentTitle={__(`You currently don't have any ${selectedContentType}.`)}
      emptySearchTitle={__(`No matching ${selectedContentType} found`)}
      emptyContentBody={__(`${selectedContentType} will appear here when created.`)}
      emptySearchBody={__('Try changing your search settings.')}
      fetchItems={useCallback(
        params =>
          getContent(contentTypes[selectedContentType][1], params),
        [contentTypes, selectedContentType],
      )}
      actionButtons={
        <SelectableDropdown
          items={Object.keys(contentTypes)}
          title={__('Type')}
          selected={selectedContentType}
          setSelected={setSelectedContentType}
          placeholderText={__('Type')}
          loading={false}
          error={false}
        />
      }
    >
      <Thead>
        <Tr>
          {columnHeaders.map(col =>
            <Th key={col.title}>{col.title}</Th>)}
        </Tr>
      </Thead>
      <Tbody>
        {results?.map(details => (
          <Tr key={`${details.id}`}>
            {buildRows(details)}
          </Tr>
        ))
        }
      </Tbody>
    </TableWrapper>
  );
};

ContentTable.propTypes = {
  selectedContentType: PropTypes.string.isRequired,
  setSelectedContentType: PropTypes.func.isRequired,
  contentTypes: PropTypes.objectOf(PropTypes.array).isRequired,
};

export default ContentTable;
